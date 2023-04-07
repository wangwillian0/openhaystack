mod api;
use std::env;

fn hex_to_u8_array(hex: &str) -> Vec<u8> {
    let mut bytes = Vec::new();
    for i in 0..hex.len() / 2 {
        let byte = u8::from_str_radix(&hex[i * 2..i * 2 + 2], 16).unwrap();
        bytes.push(byte);
    }
    bytes
}

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() != 3 {
        println!("Usage: {} <private key> <public key (uncompressed)>", args[0]);
        println!("Examples:");
        println!("  {} af0181e90420508e39e9d862f1680dc22f5f024fcfc11939d7c6fedb 0457e0910e4a34933c1ad3034ad92504c8324b8701e56c37716bf541967813d3ff1390e5c1d0c833f1fce3ff8bc69b277a072c3c31b239aacf", args[0]);
        println!("  {} 14447aec7d78c691d0c1c94da1a6a85d9eefeddf8b42f51aa227376c 04bcf74addac6c83a587eeb6d2a724158cebaecfed0af82a90434268e03c82f21e137c7341a70c0044ed058d5fe6c7aa38eb16542fdf5ae111", args[0]);
        return;
    }

    let private_key = hex_to_u8_array(&args[1]);
    let public_key = hex_to_u8_array(&args[2]);

    let shared_secret = api::ecdh(public_key, private_key);

    for i in 0..shared_secret.len() {
        print!("{:02x}", shared_secret[i]);
    }
}

