FROM rust:1.72

RUN apt update && apt install net-tools
WORKDIR /app

COPY Cargo.toml Cargo.lock ./
COPY ./src src

ENV CARGO_BUILD_TARGET_DIR=/tmp/target

RUN cargo build --release
ENTRYPOINT ["/tmp/target/release/hello"]

