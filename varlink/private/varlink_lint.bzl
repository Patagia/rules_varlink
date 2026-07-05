"""varlink_lint rule: validates a .varlink interface file without generating code."""

def varlink_lint(name, interface, visibility = None, **kwargs):
    """Validate a varlink_library interface file at build time.

    Runs the varlink-rust-generator with --nosource and discards output,
    producing a sentinel file on success.  Build errors surface before any
    Rust compilation starts.

    Args:
        name: target name; the sentinel output is <name>.lint.
        interface: label of a varlink_library target to validate.
        visibility: passed through to the genrule.
        **kwargs: forwarded to the genrule.
    """
    native.genrule(
        name = name,
        srcs = [interface],
        outs = [name + ".lint"],
        cmd = "$(location @rules_varlink//varlink/toolchain/rust:varlink_rust_generator) --nosource $(location {}) >/dev/null && touch $@".format(interface),
        tools = ["@rules_varlink//varlink/toolchain/rust:varlink_rust_generator"],
        visibility = visibility,
        **kwargs
    )
