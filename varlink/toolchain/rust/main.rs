// varlink-rust-generator CLI: reads a .varlink interface file and emits Rust bindings to stdout.
// Source logic mirrors varlink_generator 13.x src/bin/varlink-rust-generator.rs.

extern crate varlink_generator;

use std::env;
use std::fs::File;
use std::io;
use std::io::{Read, Write};
use std::path::Path;

use varlink_generator::{generate_with_options, GeneratorOptions};

fn format(src: &[u8]) -> Option<Vec<u8>> {
    let src = std::str::from_utf8(src).ok()?;
    let file = syn::parse_file(src).ok()?;
    Some(prettyplease::unparse(&file).into_bytes())
}

fn print_usage(program: &str, opts: &getopts::Options) {
    let brief = format!("Usage: {} [OPTIONS] [VARLINK FILE]", program);
    print!("{}", opts.usage(&brief));
}

fn main() -> std::result::Result<(), Box<dyn std::error::Error>> {
    let args: Vec<_> = env::args().collect();
    let program = args[0].clone();

    let mut opts = getopts::Options::new();
    opts.optflag("h", "help", "print this help menu");
    opts.optflag("", "nosource", "don't print doc header and allow");
    opts.optflag("", "async", "generate async code");

    let matches = match opts.parse(&args[1..]) {
        Ok(m) => m,
        Err(f) => {
            eprintln!("{}", f);
            print_usage(&program, &opts);
            return Err("Invalid Arguments".into());
        }
    };

    if matches.opt_present("h") {
        print_usage(&program, &opts);
        return Ok(());
    }

    let tosource = !matches.opt_present("nosource");
    let generate_async = matches.opt_present("async");

    let options = GeneratorOptions {
        generate_async,
        ..Default::default()
    };

    let mut reader: Box<dyn Read> = match matches.free.len() {
        0 => Box::new(io::stdin()),
        _ => {
            if matches.free[0] == "-" {
                Box::new(io::stdin())
            } else {
                Box::new(
                    File::open(Path::new(&matches.free[0]))
                        .map_err(|e| format!("Failed to open '{}': {e}", &matches.free[0]))?,
                )
            }
        }
    };
    let mut buf: Vec<u8> = Vec::new();
    generate_with_options(&mut reader, &mut buf, &options, tosource)?;
    let out = format(&buf).unwrap_or(buf);
    io::stdout().write_all(&out)?;
    Ok(())
}
