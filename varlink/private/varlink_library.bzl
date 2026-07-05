"""varlink_library rule: carries .varlink source files via VarlinkInfo."""

load("//varlink:providers.bzl", "VarlinkInfo")

def _varlink_library_impl(ctx):
    transitive = [dep[VarlinkInfo].srcs for dep in ctx.attr.deps]
    srcs = depset([ctx.file.src], transitive = transitive)
    return [
        VarlinkInfo(srcs = srcs, direct_srcs = [ctx.file.src]),
        DefaultInfo(files = depset([ctx.file.src])),
    ]

varlink_library = rule(
    implementation = _varlink_library_impl,
    attrs = {
        "src": attr.label(
            mandatory = True,
            allow_single_file = [".varlink"],
            doc = "The .varlink interface definition file.",
        ),
        "deps": attr.label_list(
            providers = [VarlinkInfo],
            doc = "Other varlink_library targets imported by this interface.",
        ),
    },
    doc = "Declares a Varlink interface definition file.",
)
