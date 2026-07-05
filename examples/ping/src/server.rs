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
        "org.example",
        "Ping Example",
        "1.0",
        "https://example.org",
        vec![Box::new(ping_rust::new(Box::new(PingImpl)))],
    );

    if let Err(e) = listen(
        service,
        &addr,
        &ListenConfig {
            idle_timeout: 30,
            ..Default::default()
        },
    ) {
        if *e.kind() != varlink::ErrorKind::Timeout {
            return Err(e);
        }
    }
    Ok(())
}
