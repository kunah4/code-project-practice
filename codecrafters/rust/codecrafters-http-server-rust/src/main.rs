use std::net::TcpListener;
use std::io::{Read, Write};
use std::thread;
use std::env;
use std::fs;
use std::path::PathBuf;

fn main() {
    println!("Logs from your program will appear here!");

    // parse d line args
    let args: Vec<String> = env::args().collect();
    let mut directory: Option<String> = None;

    // look for --directory arg
    for i in 0..args.len() {
        if args[i] == "--directory" && i + 1 < args.len() {
            directory = Some(args[i + 1].clone());
            break;
        }
    }
    
    let listener = TcpListener::bind("127.0.0.1:4221").unwrap();
    
    for stream in listener.incoming() {
        match stream {
            Ok(mut stream) => {
                println!("Accepted new connection");

                let dir = directory.clone();

                thread::spawn(move || {
                    handle_request(&mut stream, dir);
                });
            }
            Err(e) => {
                println!("error: {}", e);
            }
        }
    }
}

fn handle_request(stream: &mut std::net::TcpStream, directory: Option<String>) {
    let mut buf = [0; 4096];
    
    match stream.read(&mut buf) {
        Ok(0) => {
            println!("Client disconnected");
            return;
        }
        Ok(bytes_read) => {
            let req = String::from_utf8_lossy(&buf[..bytes_read]);
            let lines: Vec<&str> = req.lines().collect();
            
            if let Some(request_line) = lines.first() {
                let parts: Vec<&str> = request_line.split_whitespace().collect();
                
                // see the parts
                // for part in &parts {
                //     println!("part: {}", part);
                // }

                let parts_len_gt_3 = parts.len() >= 3;
                let not_found = "HTTP/1.1 404 Not Found\r\n\r\n";
                
                if parts_len_gt_3 && parts[1] == "/" {
                    // Handle root enpoint
                    let response = "HTTP/1.1 200 OK\r\n\r\n";
                    let _ = stream.write_all(response.as_bytes());
                    let _ = stream.write_all("Hello World!".as_bytes());
                } else if parts_len_gt_3 && parts[1].starts_with("/echo") {
                    // Handle echo enpoint
                    let echo_content = parts[1].replace("/echo", "").replace("/", "");
                    let content_type = "Content-Type: text/plain\r\n";
                    let content_length = format!("Content-Length: {}\r\n\r\n", echo_content.len());
                    let response = format!(
                        "HTTP/1.1 200 OK\r\n{}{}",
                        content_type,
                        content_length
                    );
                    let _ = stream.write_all(response.as_bytes());
                    let _ = stream.write_all(echo_content.as_bytes());
                    
                } else if parts_len_gt_3 && parts[1].to_lowercase() == "/user-agent" {
                    // Handle User-Agent endpoint (case-insensitive)
                    let mut user_agent = "";
                    for line in lines.iter().skip(1) {
                        if line.to_lowercase().starts_with("user-agent:") {
                            if let Some(v) = line.split_once(": ").map(|(_, v)| v) {
                                user_agent = v;
                                break;
                            }
                        }
                    }
                    let content_type = "Content-Type: text/plain\r\n";
                    let content_length = format!("Content-Length: {}\r\n\r\n", user_agent.len());
                    let response = format!(
                        "HTTP/1.1 200 OK\r\n{}{}",
                        content_type,
                        content_length
                    );
                    let _ = stream.write_all(response.as_bytes());
                    let _ = stream.write_all(&user_agent.as_bytes());
                    
                } else if parts_len_gt_3 && parts[0] == "GET" && parts[1].starts_with("/files/") {
                    // Handle files/{filename} endpoint -> GET
                    if let Some(ref dir) = directory {
                        let filename = &parts[1][7..];   // remove "/files/" prefix
                        let file_path = PathBuf::from(dir).join(filename);

                        match fs::read(&file_path) {
                            Ok(contents) => {
                                let response = format!(
                                    "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: {}\r\n\r\n",
                                    contents.len()
                                );
                                let _ = stream.write_all(response.as_bytes());
                                let _ = stream.write_all(&contents);
                            }
                            Err(_) => {
                                // File not found or error reading file
                                let _ = stream.write_all(not_found.as_bytes());
                            }
                        }
                    } else {
                        // No directory specified
                        let _ = stream.write_all(not_found.as_bytes());
                    }
                    
                } else if parts.len() >= 3 && parts[0] == "POST" && parts[1].starts_with("/files/") {
                    // Handle file creation (POST)
                    if let Some(ref dir) = directory {
                        let filename = &parts[1][7..]; // Remove "/files/" prefix
                        let file_path = PathBuf::from(dir).join(filename);
                        
                        // // Find Content-Length header
                        // let mut content_length = 0;
                        // for line in lines.iter().skip(1) {
                        //     if line.to_lowercase().starts_with("content-length:") {
                        //         if let Some((_, value)) = line.split_once(": ") {
                        //             content_length = value.parse().unwrap_or(0);
                        //             break;
                        //         }
                        //     }
                        // }
                        
                        // Find the empty line separating headers from body
                        let body_start = req.find("\r\n\r\n").unwrap_or(0) + 4;
                        
                        // Extract body content
                        let body = if body_start < bytes_read {
                            &buf[body_start..bytes_read]
                        } else {
                            &[]
                        };
                        
                        // write request body to file
                        match fs::write(&file_path, body) {
                            Ok(_) => {
                                let response = "HTTP/1.1 201 Created\r\n\r\n";
                                let _ = stream.write_all(response.as_bytes());
                            }
                            Err(_) => {
                                let response = "HTTP/1.1 500 Internal Server Error\r\n\r\n";
                                let _ = stream.write_all(response.as_bytes());
                            }
                        }
                    } else {
                        // No directory specified
                        let _ = stream.write_all(not_found.as_bytes());
                    }
                
                } else {
                    // Return 404 for any other path
                    let _ = stream.write_all(not_found.as_bytes());
                }
            }
        }
        Err(e) => {
            println!("Failed to read from client: {}", e);
            return;
        }
    }
}