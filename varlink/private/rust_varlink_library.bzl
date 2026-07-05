"""rust_varlink_library macro: generates a rust_library from a varlink_library target."""

load("@rules_rs//rs:rust_library.bzl", "rust_library")

def rust_varlink_library(name, interface, generate_async = False, crate_name = None, visibility = None, **kwargs):
    """Generate a Rust library from a varlink_library target.

    Args:
        name: target name; also used as crate_name if crate_name is not set.
        interface: label of a varlink_library target.
        generate_async: if True, generate the tokio async API (--async flag).
        crate_name: override the Rust crate name (defaults to name).
        visibility: passed through to the rust_library.
        **kwargs: forwarded to rust_library.
    """
    gen_name = name + "_gen"
    out = name + ".rs"

    args = ["$(location {})".format(interface)]
    if generate_async:
        args = ["--async"] + args

    native.genrule(
        name = gen_name,
        srcs = [interface],
        outs = [out],
        cmd = "$(location @rules_varlink//varlink/toolchain/rust:varlink_rust_generator) {} > $@".format(
            " ".join(args),
        ),
        tools = ["@rules_varlink//varlink/toolchain/rust:varlink_rust_generator"],
    )

    rust_library(
        name = name,
        srcs = [":" + gen_name],
        crate_name = crate_name or name.replace("-", "_"),
        edition = "2021",
        deps = [
            Label("@varlink_crates//:varlink"),
            Label("@varlink_crates//:serde"),
            Label("@varlink_crates//:serde_derive"),
            Label("@varlink_crates//:serde_json"),
        ],
        visibility = visibility,
        **kwargs
    )
