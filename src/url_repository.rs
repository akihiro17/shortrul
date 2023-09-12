use mysql::prelude::*;
use mysql::*;
use regex::Regex;
use thiserror::Error;

use crate::url::Url;

#[derive(Debug, Error)]
pub enum CustomError {
    #[error("Not Found Error")]
    NotFound,
    #[error("Duplicate Key")]
    DuplicateEntry,
    #[error("MySQL error")]
    MySQLErr(#[from] mysql::Error),
    #[error("Regex error")]
    RegexErr(#[from] regex::Error),
}

#[derive(FromRow)]
struct UrlEntity {
    id: i64,
    long_url: String,
    short_url: String,
}

impl From<UrlEntity> for Url {
    fn from(entity: UrlEntity) -> Url {
        Url {
            id: entity.id,
            long_url: entity.long_url,
            short_url: entity.short_url,
        }
    }
}

pub struct UrlRepository<'c> {
    pub conn: &'c mut PooledConn,
}

impl<'c> UrlRepository<'c> {
    pub fn find_by_longurl(&mut self, long_url: &str) -> Result<Url, CustomError> {
        match self.conn.exec_first::<UrlEntity, &str, Params>(
            "SELECT id, long_url, short_url from urls where long_url = :long_url",
            params! { "long_url" => long_url},
        ) {
            Ok(Some(row)) => Ok(Url::from(row)),
            Ok(None) => Err(CustomError::NotFound),
            Err(e) => Err(CustomError::MySQLErr(e)),
        }
    }

    pub fn find_by_shorturl(&mut self, short_url: &str) -> Result<Url, CustomError> {
        match self.conn.exec_first::<UrlEntity, &str, Params>(
            "SELECT id, long_url, short_url from urls where short_url = :short_url",
            params! { "short_url" => short_url},
        ) {
            Ok(Some(row)) => Ok(Url::from(row)),
            Ok(None) => Err(CustomError::NotFound),
            Err(e) => Err(CustomError::MySQLErr(e)),
        }
    }

    pub fn insert(&mut self, id: u64, long_url: &str, short_url: &str) -> Result<(), CustomError> {
        match self.conn.exec_drop(
            "insert into urls (id, long_url, short_url) values (:id, :long_url, :short_url)",
            params! {
                "id" => id,
                "long_url" => long_url,
                "short_url" => &short_url,
            },
        ) {
            Ok(_) => {
                return Ok(());
            }
            Err(e) => {
                let duplicate_entry = match Regex::new(r"Duplicate entry") {
                    Ok(r) => r,
                    Err(e) => {
                        return Err(CustomError::RegexErr(e));
                    }
                };

                if let Some(_) = duplicate_entry.captures(&e.to_string()) {
                    Err(CustomError::DuplicateEntry)
                } else {
                    Err(CustomError::MySQLErr(e))
                }
            }
        }
    }
}
