use varlink::Connection;

use ping_rust::{VarlinkClient, VarlinkClientInterface};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let addr = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "unix:/tmp/org.example.ping".to_string());

    let connection = Connection::new(&addr)?;
    let mut client = VarlinkClient::new(connection);

    let msg = std::env::args().nth(2).unwrap_or_else(|| "Hello, varlink!".to_string());
    let pong = client.ping(msg.clone()).call()?.pong;
    assert_eq!(pong, msg, "pong must echo the ping");
    println!("{pong}");
    Ok(())
}
