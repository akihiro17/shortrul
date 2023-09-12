FROM rust:1.72 as builder

RUN apt update && apt install net-tools
WORKDIR /app

COPY Cargo.toml Cargo.lock ./
COPY ./src src

ENV CARGO_BUILD_TARGET_DIR=/tmp/target

RUN cargo build --release

FROM debian:bookworm-slim
COPY --from=builder /tmp/target/release/shorturl /app
ENTRYPOINT ["/app"]

