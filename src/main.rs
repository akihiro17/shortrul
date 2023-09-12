use mysql::*;
use rand::Rng;
use regex::Regex;
use snowflaked::Generator;
use std::env;

use shorturl::url_repository;
use shorturl::url_repository::CustomError;
use shorturl::urlshorter;
use shorturl::ThreadPool;

use std::{
    io::{Read, Write},
    net::{TcpListener, TcpStream},
};

fn main() {
    // mysql settings
    let mysql_user = match env::var("MYSQL_USER") {
        Ok(user) => user,
        Err(_) => "root".to_owned(),
    };
    let mysql_password = match env::var("MYSQL_PASSWORD") {
        Ok(password) => password,
        Err(_) => "password".to_owned(),
    };
    let mysql_host = match env::var("MYSQL_HOST") {
        Ok(val) => val,
        Err(_) => "localhost".to_owned(),
    };
    let mysql_port = match env::var("MYSQL_PORT") {
        Ok(val) => val,
        Err(_) => "3306".to_owned(),
    };
    let mysql_database_name = match env::var("MYSQL_DATABASE_NAME") {
        Ok(val) => val,
        Err(_) => "developments".to_owned(),
    };
    let database_url = format!(
        "mysql://{}:{}@{}:{}/{}",
        mysql_user, mysql_password, mysql_host, mysql_port, mysql_database_name,
    );
    let database_url = Opts::from_url(&database_url).unwrap();
    let connection_pool = Pool::new(database_url).unwrap();

    // listen
    let listen_port = match env::var("LISTEN_PORT") {
        Ok(val) => val,
        Err(_) => "7878".to_owned(),
    };
    let addr = format!("0.0.0.0:{}", listen_port);
    let listner = TcpListener::bind(addr).unwrap();
    let pool = ThreadPool::new(4);
    println!("started");

    // accepet
    for stream in listner.incoming() {
        let stream = stream.unwrap();
        // https://docs.rs/mysql/24.0.0/mysql/#pool
        let cloned = connection_pool.clone();
        // TODO: must generate unique instance id
        let mut rng = rand::thread_rng();
        let instance_id = rng.gen_range(0..(2 ^ 10));
        pool.execute(move || {
            let mut c = cloned.get_conn().unwrap();
            handle_connection(stream, instance_id, &mut c);
        });
    }
}

fn handle_connection(mut stream: TcpStream, instance_id: u16, conn: &mut PooledConn) {
    let mut buffer = [0; 1024];
    stream.read(&mut buffer).unwrap();

    let healthcheck_url_path = Regex::new(r"GET \/healthcheck HTTP\/1.1").unwrap();
    let shorten_url_path =
        Regex::new(r"POST \/api\/v1\/data\/shorten\?longURL=(.+) HTTP\/1.1").unwrap();
    let get_long_url_path = Regex::new(r"GET \/api\/v1\/short\/(.+) HTTP\/1.1").unwrap();
    let line = String::from_utf8_lossy(&buffer[..]);

    println!("Request: {}", line);

    if let Some(_) = healthcheck_url_path.captures(&line) {
        let response = format!("HTTP/1.1 200 OK\r\n\r\n");
        stream.write(response.as_bytes()).unwrap();
        stream.flush().unwrap();
    } else if let Some(caps) = shorten_url_path.captures(&line) {
        let long_url = &caps[1];
        shorten_url(stream, instance_id, conn, long_url);
    } else if let Some(caps) = get_long_url_path.captures(&line) {
        let short_url = &caps[1];
        get_long_url(stream, conn, short_url);
    } else {
        let response = format!("HTTP/1.1 404 Not Found\r\n\r\n");
        stream.write(response.as_bytes()).unwrap();
        stream.flush().unwrap();
    }
}

fn shorten_url(
    mut stream: TcpStream,
    instance_id: u16,
    conn: &mut PooledConn,
    long_url: &str,
) -> () {
    let mut generator = Generator::new(instance_id);
    let id: u64 = generator.generate();
    let short_url = urlshorter::shorten(id);

    let mut url_repo = url_repository::UrlRepository { conn: conn };

    match url_repo.insert(id, long_url, &short_url) {
        Ok(_) => {
            println!("the unique id: {} for {}", id, long_url);
            let response = format!("HTTP/1.1 200 OK\r\n\r\n{}\r\n", &short_url);
            stream.write(response.as_bytes()).unwrap();
            stream.flush().unwrap();
        }
        Err(CustomError::DuplicateEntry) => match url_repo.find_by_longurl(long_url) {
            Ok(row) => {
                let response = format!("HTTP/1.1 200 OK\r\n\r\n{}\r\n", row.short_url);
                stream.write(response.as_bytes()).unwrap();
                stream.flush().unwrap();
                return;
            }
            Err(CustomError::NotFound) => {
                println!("something is wrong with the long_url({}) ", long_url);
                let response = format!("HTTP/1.1 404 Not Found\r\n\r\n");
                stream.write(response.as_bytes()).unwrap();
                stream.flush().unwrap();
                return;
            }
            Err(e) => {
                println!(
                    "error occured while getting urls from {}\r\n{}",
                    long_url, e
                );
                let response = format!("HTTP/1.1 503 Service Unavailable\r\n\r\n");
                stream.write(response.as_bytes()).unwrap();
                stream.flush().unwrap();
            }
        },
        Err(e) => {
            println!(
                "failed to insert records(long_url: {}, short_url: {})\r\n{}",
                long_url, &short_url, e,
            );

            let response = format!("HTTP/1.1 503 Service Unavailable\r\n\r\n");
            stream.write(response.as_bytes()).unwrap();
            stream.flush().unwrap();
        }
    }
}

fn get_long_url(mut stream: TcpStream, conn: &mut PooledConn, short_url: &str) -> () {
    let mut url_repo = url_repository::UrlRepository { conn: conn };

    match url_repo.find_by_shorturl(short_url) {
        Ok(row) => {
            let response = format!("HTTP/1.1 200 OK\r\n\r\n{}\r\n", &row.long_url);
            stream.write(response.as_bytes()).unwrap();
            stream.flush().unwrap();
            return;
        }
        Err(CustomError::NotFound) => {
            println!("long_url not found(short_url: {}) ", short_url);
            let response = format!("HTTP/1.1 404 Not Found\r\n\r\n");
            stream.write(response.as_bytes()).unwrap();
            stream.flush().unwrap();
            return;
        }
        Err(e) => {
            println!(
                "error occured while getting urls from {}\r\n{}",
                short_url, e
            );
            let response = format!("HTTP/1.1 503 Service Unavailable\r\n\r\n");
            stream.write(response.as_bytes()).unwrap();
            stream.flush().unwrap();
        }
    }
}
