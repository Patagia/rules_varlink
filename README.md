# rules_varlink

Bazel rules for [Varlink](https://varlink.org/) interface definitions, with first-class support for Rust code generation.

Varlink is a network protocol for inter-process communication. You describe an interface once in a `.varlink` file and generate type-safe client/server bindings. rules_varlink automates that generation step inside a Bazel build.

## What it provides

- **`varlink_library`** — declares a `.varlink` interface file as a Bazel target, carrying it through the dependency graph via `VarlinkInfo`.
- **`rust_varlink_library`** — generates a Rust crate from a `varlink_library` target using the `varlink-rust-generator` tool (built from crates.io, no pre-built binaries required).
- **`varlink_lint`** — validates a `.varlink` interface file at build time without generating any Rust code.
- A hermetic `varlink_rust_generator` toolchain binary available at `//varlink/toolchain:varlink_rust_generator`.

## Setup

Add to your `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_varlink", version = "0.0.1")
bazel_dep(name = "rules_rs", version = "0.0.82")
bazel_dep(name = "llvm", version = "0.8.3")

rules_rust = use_extension("@rules_rs//rs:rules_rust.bzl", "rules_rust")
use_repo(rules_rust, "rules_rust")

rust_toolchains = use_extension("@rules_rs//rs/toolchains:module_extension.bzl", "toolchains")
rust_toolchains.toolchain(
    edition = "2021",
    version = "1.95.0",
)
use_repo(rust_toolchains, "default_rust_toolchains")

register_toolchains(
    "@default_rust_toolchains//:all",
    "@llvm//toolchain:all",
)
```

The `llvm` dep is required because rules_rs toolchains carry `@llvm//constraints/libc:gnu.2.28` in their `target_compatible_with`. Without it, Bazel cannot resolve `@llvm` from your root module even though it is a transitive dependency of rules_rs.

If you are on NixOS (or another system where `libgcc_s` is not on the default library search path), add to your `.bazelrc`:

```
common:linux --@llvm//config:experimental_stub_libgcc_s=True
```

## Usage

### 1. Declare the interface

```python
# interfaces/BUILD.bazel
load("@rules_varlink//varlink:defs.bzl", "varlink_library", "rust_varlink_library", "varlink_lint")

varlink_library(
    name = "ping",
    src = "org.example.ping.varlink",
)

varlink_lint(
    name = "ping_lint",
    interface = ":ping",
)

rust_varlink_library(
    name = "ping_rust",
    interface = ":ping",
    visibility = ["//visibility:public"],
)
```

`varlink_lint` is a build-time check (not a test): it runs the generator with `--nosource` and discards the output, touching a sentinel `.lint` file on success. Errors report the exact line and column:

```
Error: Parse(Parse { line: "bad syntax here", column: 1 })
```

This runs during `bazel build`, so interface parse errors surface before any Rust compilation starts.

```varlink
# interfaces/org.example.ping.varlink
interface org.example.ping

method Ping(ping: string) -> (pong: string)
```

### 2. Implement the server

```python
# BUILD.bazel
load("@rules_rs//rs:rust_binary.bzl", "rust_binary")

rust_binary(
    name = "server",
    srcs = ["src/server.rs"],
    edition = "2021",
    deps = [
        "//interfaces:ping_rust",
        "@rules_varlink//varlink/runtime:varlink",
    ],
)
```

```rust
use varlink::{listen, ListenConfig, VarlinkService};
use ping_rust::{self, Call_Ping, VarlinkInterface};

struct PingImpl;

impl VarlinkInterface for PingImpl {
    fn ping(&self, call: &mut dyn Call_Ping, ping: String) -> varlink::Result<()> {
        call.reply(ping)
    }
}

fn main() -> varlink::Result<()> {
    let addr = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "unix:/tmp/org.example.ping".to_string());
    let service = VarlinkService::new(
        "org.example", "My Service", "1.0", "https://example.org",
        vec![Box::new(ping_rust::new(Box::new(PingImpl)))],
    );
    listen(service, &addr, &ListenConfig { idle_timeout: 30, ..Default::default() })
        .or_else(|e| if *e.kind() == varlink::ErrorKind::Timeout { Ok(()) } else { Err(e) })
}
```

### 3. Implement the client

```rust
use varlink::Connection;
use ping_rust::{VarlinkClient, VarlinkClientInterface};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let addr = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "unix:/tmp/org.example.ping".to_string());
    let connection = Connection::new(&addr)?;
    let mut client = VarlinkClient::new(connection);
    let pong = client.ping("hello".to_string()).call()?.pong;
    println!("{pong}");
    Ok(())
}
```

## Public API

Load all rules from the single public entry point:

```python
load("@rules_varlink//varlink:defs.bzl", "varlink_library", "varlink_lint", "rust_varlink_library")
```

### `varlink_library`

| Attribute | Type | Description |
|-----------|------|-------------|
| `src` | label | The `.varlink` interface definition file. Mandatory. |
| `deps` | list of labels | Other `varlink_library` targets imported by this interface. |

Propagates `VarlinkInfo` (a depset of `.varlink` files) through the dependency graph.

### `rust_varlink_library`

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | string | — | Target name; also used as crate name unless `crate_name` is set. |
| `interface` | label | — | A `varlink_library` target. Mandatory. |
| `generate_async` | bool | `False` | Generate the tokio async API (`--async` flag to the generator). |
| `crate_name` | string | `name` (with `-` → `_`) | Override the Rust crate name. |
| `visibility` | list | — | Passed through to the underlying `rust_library`. |
| `**kwargs` | — | — | Forwarded to `rust_library`. |

The generated crate includes `varlink`, `serde`, `serde_derive`, and `serde_json` as dependencies automatically — callers do not need to declare them.

### `varlink_lint`

| Attribute | Type | Description |
|-----------|------|-------------|
| `name` | string | Target name; sentinel output is `<name>.lint`. |
| `interface` | label | A `varlink_library` target to validate. Mandatory. |
| `visibility` | list | Passed through to the genrule. |
| `**kwargs` | — | Forwarded to the genrule. |

### `@rules_varlink//varlink/runtime:varlink`

An alias to the `varlink 13.x` runtime crate. Use this in `deps` of binaries that import generated varlink types directly (e.g. to call `Connection::new` or `VarlinkService::new`). Consumers do not need `@varlink_crates` in their own module.

## Example

A complete working example lives in [`examples/ping/`](examples/ping/). It demonstrates:

- A `varlink_library` + `rust_varlink_library` pair for a single-method interface.
- A synchronous server binary with `idle_timeout`.
- A client binary using the generated `VarlinkClient`.
- A `varlink_lint` build-time validation target.
- An integration `sh_test` that starts the server, calls the client, and asserts the echoed response.
- A generator error `sh_test` that verifies malformed `.varlink` input is rejected.

```
bazel test //...
```

## Current limitations

- **Rust only.** No bindings are generated for other languages (C, Python, Go, …).
- **Sync API only by default.** Async (tokio) code generation is supported via `generate_async = True` but is not tested in the example.
- **x86_64-unknown-linux-gnu / musl only.** The generator toolchain and runtime crates are currently pinned to those two platform triples.

## License

Mozilla Public License 2.0 — see [LICENSE](LICENSE).
