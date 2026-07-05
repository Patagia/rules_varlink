VarlinkInfo = provider(
    doc = "Varlink interface sources and transitive dependencies.",
    fields = {
        "srcs": "depset of .varlink files (direct + transitive).",
        "direct_srcs": "list of .varlink files declared by this target only.",
    },
)
