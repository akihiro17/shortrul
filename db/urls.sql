CREATE DATABASE IF NOT EXISTS developments;
CREATE TABLE IF NOT EXISTS developments.urls (
  id BIGINT PRIMARY KEY,
  long_url varchar(768) NOT NULL,
  short_url varchar(50) NOT NULL,
  UNIQUE KEY uniq_long_url (long_url)
);
