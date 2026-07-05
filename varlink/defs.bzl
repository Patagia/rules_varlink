"""Public API for rules_varlink."""

load("//varlink/private:varlink_library.bzl", _varlink_library = "varlink_library")
load("//varlink/private:rust_varlink_library.bzl", _rust_varlink_library = "rust_varlink_library")
load("//varlink/private:varlink_lint.bzl", _varlink_lint = "varlink_lint")

varlink_library = _varlink_library
rust_varlink_library = _rust_varlink_library
varlink_lint = _varlink_lint
