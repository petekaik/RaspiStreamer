# Käytetään Debian Bullseye -versiota (bookwormia edeltävä)
FROM debian:bullseye-slim

# Päivitykset ja tarvittavat työkalut
RUN apt-get update && apt-get install -y \
    build-essential \
    libasound2-dev \
    libpulse-dev \
    libavahi-compat-libdnssd-dev \
    pkg-config \
    curl \
    git \
    cmake \
    file \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Asenna Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Lisää ARMv6-ristiinkääntäjä
RUN rustup target add arm-unknown-linux-gnueabihf

# Asenna cross-linkkeri
RUN apt-get update && apt-get install -y gcc-arm-linux-gnueabihf && rm -rf /var/lib/apt/lists/*

# Luodaan työskentelyhakemisto
WORKDIR /workspace

# Kopioidaan lähdekoodi Dockerin sisään
COPY . .

# Cargo config ristiinkäännölle
RUN mkdir -p .cargo
RUN echo '[target.arm-unknown-linux-gnueabihf]' >> .cargo/config.toml
RUN echo 'linker = "arm-linux-gnueabihf-gcc"' >> .cargo/config.toml

# Käännetään PulseAudio + Avahi + TLS
RUN cargo build --release --target arm-unknown-linux-gnueabihf --no-default-features --features "native-tls,pulseaudio-backend,with-avahi"

# Lopputulos containerissa: /workspace/target/arm-unknown-linux-gnueabihf/release/librespot
