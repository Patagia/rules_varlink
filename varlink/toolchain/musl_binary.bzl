"""musl_binary: wraps a rust_binary and builds it for x86_64-unknown-linux-musl.

Using the musl platform for exec tools avoids the glibc/libcxx runtime on NixOS
hosts where the LLVM CC toolchain's libcxx.static link-order differs from
what rustc generates.
"""

def _to_musl_impl(_settings, _attr):
    return {"//command_line_option:platforms": str(Label("@rules_rs//rs/platforms:x86_64-unknown-linux-musl"))}

_to_musl = transition(
    implementation = _to_musl_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _musl_binary_impl(ctx):
    target = ctx.attr.binary[0]
    src = target[DefaultInfo].files_to_run.executable
    out = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(output = out, target_file = src, is_executable = True)
    return [DefaultInfo(
        executable = out,
        runfiles = ctx.runfiles(files = [out]).merge(target[DefaultInfo].default_runfiles),
    )]

musl_binary = rule(
    doc = "Wraps an executable, building it (and all deps) for static musl.",
    implementation = _musl_binary_impl,
    attrs = {
        "binary": attr.label(
            cfg = _to_musl,
            executable = True,
            mandatory = True,
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    executable = True,
)
