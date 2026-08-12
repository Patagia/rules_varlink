"""rust_varlink_library macro: generates a rust_library from a varlink_library target."""

load("@rules_rs//rs:rust_library.bzl", "rust_library")
load("//varlink:providers.bzl", "VarlinkInfo")

def _varlink_rust_gen_impl(ctx):
    varlink_info = ctx.attr.interface[VarlinkInfo]
    src = varlink_info.direct_srcs[0]
    out = ctx.actions.declare_file(ctx.attr.out)

    args = ["--async"] if ctx.attr.generate_async else []
    ctx.actions.run_shell(
        inputs = varlink_info.srcs,
        outputs = [out],
        tools = [ctx.executable._generator],
        command = "{generator} {args} {src} > {out}".format(
            generator = ctx.executable._generator.path,
            args = " ".join(args),
            src = src.path,
            out = out.path,
        ),
        mnemonic = "VarlinkRustGen",
        progress_message = "Generating Rust varlink bindings for %{label}",
    )

    return [
        DefaultInfo(files = depset([out])),
        # Lets rust_analyzer_aspect materialize the generated file for go-to-def.
        OutputGroupInfo(rust_generated_srcs = depset([out])),
    ]

_varlink_rust_gen = rule(
    implementation = _varlink_rust_gen_impl,
    attrs = {
        "generate_async": attr.bool(default = False),
        "interface": attr.label(
            mandatory = True,
            providers = [VarlinkInfo],
            doc = "varlink_library target to generate bindings from.",
        ),
        "out": attr.string(
            mandatory = True,
            doc = "Name of the generated .rs file.",
        ),
        "_generator": attr.label(
            default = Label("//varlink/toolchain/rust:varlink_rust_generator"),
            executable = True,
            cfg = "exec",
        ),
    },
    doc = "Runs varlink-rust-generator and exposes the output via rust_generated_srcs.",
)

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

    _varlink_rust_gen(
        name = gen_name,
        interface = interface,
        generate_async = generate_async,
        out = name + ".rs",
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
