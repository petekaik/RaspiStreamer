FROM arm32v6/debian:bullseye

RUN apt-get update && apt-get install -y 	build-essential 	libasound2-dev 	libpulse-dev 	libavahi-compat-libdnssd-dev 	pkg-config 	curl 	git 	cmake 	file 	ca-certificates 	gcc-arm-linux-gnueabihf 	libssl-dev 	&& rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:/usr/local/bin:/Users/petekaik/Library/Application Support/Code/User/globalStorage/github.copilot-chat/debugCommand:/Users/petekaik/Library/Application Support/Code/User/globalStorage/github.copilot-chat/copilotCli:/Library/Frameworks/Python.framework/Versions/3.12/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin:/opt/pmk/env/global/bin:/Users/petekaik/Library/Application Support/Code/User/globalStorage/github.copilot-chat/debugCommand:/Users/petekaik/Library/Application Support/Code/User/globalStorage/github.copilot-chat/copilotCli:/opt/anaconda3/bin:/opt/anaconda3/condabin:/Library/Frameworks/Python.framework/Versions/3.12/bin:/Users/petekaik/.cargo/bin"

RUN rustup target add arm-unknown-linux-gnueabihf || true

WORKDIR /workspace
COPY librespot/ .

RUN mkdir -p .cargo
RUN printf '[target.%s]\nlinker = "arm-linux-gnueabihf-gcc"\n' "arm-unknown-linux-gnueabihf" >> .cargo/config.toml
RUN printf '[target.%s]\nrustflags = ["-C", "target-cpu=%s"]\n' "arm-unknown-linux-gnueabihf" "arm1176jzf-s" >> .cargo/config.toml

ENV PKG_CONFIG_PATH=/usr/arm-linux-gnueabihf/lib/pkgconfig

RUN cargo build --release --target arm-unknown-linux-gnueabihf --no-default-features --features "native-tls,pulseaudio-backend,with-avahi"
