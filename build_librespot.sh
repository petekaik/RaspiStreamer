#!/bin/bash
set -e

# --- Asetukset ---

LIBRESPOT_REPO="https://github.com/librespot-org/librespot"
TARGET_USER="pi"
TARGET_HOST="matkakajari"
TARGET_PATH="/home/pi/librespot"
CONTAINER_NAME="librespot-cross"
DOCKER_IMAGE_NAME="librespot-bullseye-armv6"
FEATURES="native-tls,pulseaudio-backend,with-avahi"
# Rust target for hard-float ARM (works for many Pi builds). We'll target arm (gnueabihf)
TARGET_TRIPLE="arm-unknown-linux-gnueabihf"
# Use an ARMv6-specific CPU tune for Raspberry Pi Zero (arm1176)
TARGET_CPU="arm1176jzf-s"
HOSTNAME="Matkakajari"
DEVICE_NAME="Matkakajari"

# --- Luo työkansio ---

WORKDIR="$(pwd)/librespot-docker"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# --- Lataa lähdekoodi ---

if [ ! -d "librespot" ]; then
echo "Clonaus GitHubista..."
git clone "$LIBRESPOT_REPO"
else
echo "Päivitetään olemassa oleva repository..."
cd librespot
git pull
cd ..
fi

# --- Luo Dockerfile ---
cat > Dockerfile <<EOF
FROM arm32v6/debian:bullseye

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
	gcc-arm-linux-gnueabihf \
	libssl-dev \
	&& rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

RUN rustup target add $TARGET_TRIPLE || true

WORKDIR /workspace
COPY librespot/ .

RUN mkdir -p .cargo
RUN printf '[target.%s]\nlinker = "arm-linux-gnueabihf-gcc"\n' "$TARGET_TRIPLE" >> .cargo/config.toml
RUN printf '[target.%s]\nrustflags = ["-C", "target-cpu=%s"]\n' "$TARGET_TRIPLE" "$TARGET_CPU" >> .cargo/config.toml

ENV PKG_CONFIG_PATH=/usr/arm-linux-gnueabihf/lib/pkgconfig

RUN cargo build --release --target $TARGET_TRIPLE --no-default-features --features "$FEATURES"
EOF


# --- Valmistele QEMU + Buildx cross-build ---
echo "Rekisteröidään QEMU emulaattorit (tarvitsee Dockerin privileged-oikeudet)..."
# Pull/run the arm64 build of the qemu-user-static image on Apple Silicon so the binary matches host
docker run --rm --privileged --platform linux/arm64 multiarch/qemu-user-static --reset -p yes

BUILDER_NAME="${CONTAINER_NAME}-builder"
if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
	echo "Luodaan ja otetaan käyttöön buildx builder: $BUILDER_NAME"
	docker buildx create --name "$BUILDER_NAME" --use
else
	echo "Käytetään olemassa olevaa buildx builderia: $BUILDER_NAME"
	docker buildx use "$BUILDER_NAME"
fi

echo "Bootstrapping buildx..."
docker buildx inspect --bootstrap

echo "Rakennetaan ARMv6-kuva buildx:llä (platform=linux/arm/v6)..."
# Use --load so the built image is available locally for docker create/cp
if docker buildx build --platform linux/arm/v6 -t $DOCKER_IMAGE_NAME --load .; then
	echo "Buildx onnistui, haetaan binääri kuvasta..."
	CONTAINER_ID=$(docker create --platform linux/arm/v6 $DOCKER_IMAGE_NAME || docker create $DOCKER_IMAGE_NAME)
	docker cp $CONTAINER_ID:/workspace/target/$TARGET_TRIPLE/release/librespot ./librespot-arm
	docker rm $CONTAINER_ID
else
	echo "Buildx epäonnistui — yritetään varmistettua fallback-rakennusta emuloidussa arm32v6-kontissa (hitaampi)."
	docker run --rm --platform linux/arm/v6 -v "$WORKDIR/librespot":/workspace -w /workspace arm32v6/debian:bullseye bash -lc '
		set -e
		apt-get update
		apt-get install -y build-essential libasound2-dev libpulse-dev libavahi-compat-libdnssd-dev pkg-config curl git cmake file ca-certificates gcc-arm-linux-gnueabihf libssl-dev
		curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
		export PATH="/root/.cargo/bin:$PATH"
		rustup target add ${TARGET_TRIPLE} || true
		mkdir -p .cargo
		printf "[target.%s]\nlinker = \"arm-linux-gnueabihf-gcc\"\n" "${TARGET_TRIPLE}" > .cargo/config.toml
		printf "[target.%s]\nrustflags = [\"-C\", \"target-cpu=${TARGET_CPU}\"]\n" "${TARGET_TRIPLE}" >> .cargo/config.toml
		export PKG_CONFIG_PATH=/usr/arm-linux-gnueabihf/lib/pkgconfig
		cargo build --release --target ${TARGET_TRIPLE} --no-default-features --features "${FEATURES}"
	'
	# After fallback build, binary should be present on host under librespot/target/... so copy it
	if [ -f "$WORKDIR/librespot/target/$TARGET_TRIPLE/release/librespot" ]; then
		cp "$WORKDIR/librespot/target/$TARGET_TRIPLE/release/librespot" ./librespot-arm
	else
		echo "Virhe: fallback-rakennus ei tuottanut odotettua binääriä. Katso konttilokin virheille." >&2
		exit 1
	fi
fi

# --- Siirrä binääri Raspberry Pi:lle ---

echo "Siirretään binääri Raspberry Pi:lle..."
scp ./librespot-arm $TARGET_USER@$TARGET_HOST:$TARGET_PATH

echo "Valmis! Binääri sijaitsee: $TARGET_PATH/librespot-arm"
echo "Testaa Pi Zerolla komennolla:"
echo "$TARGET_PATH/librespot-arm --name "$DEVICE_NAME" --bitrate 160 --enable-volume-normalisation --initial-volume 75 --device-type avr"
echo "Hostname voidaan asettaa Pi:llä komennolla: sudo hostnamectl set-hostname $HOSTNAME"
