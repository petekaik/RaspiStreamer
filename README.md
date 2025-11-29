# RaspiStreamer

Automated build of **librespot** for ARMv6 (Raspberry Pi Zero W) using GitHub Actions.

## Overview

This repository provides a GitHub Actions workflow that cross-compiles [librespot](https://github.com/librespot-org/librespot) for Debian Bullseye on Raspberry Pi Zero W (ARMv6 architecture) and packages it as a `.deb` file.

## Building

### Automated Build (GitHub Actions)

1. Push to `main` branch or manually trigger the workflow:
   - Go to GitHub → Actions → "Build librespot (armv6)" → "Run workflow"
2. The workflow will:
   - Set up QEMU and Docker Buildx for cross-compilation
   - Clone librespot from upstream
   - Build the binary in an emulated ARMv6 environment
   - Package the binary as a `.deb` file for Debian Bullseye
   - Upload the `.deb` as an artifact

### Download & Install

1. Download the `.deb` artifact from the workflow run (e.g., `librespot_<version>_armhf.deb`)
2. Transfer to your Raspberry Pi Zero W:
   ```bash
   scp librespot_<version>_armhf.deb pi@raspberrypi:/home/pi/
   ```
3. Install on the Pi:
   ```bash
   ssh pi@raspberrypi
   sudo dpkg -i /home/pi/librespot_<version>_armhf.deb
   sudo apt-get -f install  # Fix any missing dependencies
   ```

## Running librespot

After installation, run:

```bash
librespot --name "MyDeviceName" --bitrate 160 --enable-volume-normalisation
```

See `librespot --help` for more options.

## Troubleshooting

- **Dependency errors**: If the `.deb` install fails, run `sudo apt-get -f install` to resolve.
- **Build failures**: Check the GitHub Actions logs for details.

## Files

- `.github/workflows/build-armv6.yml` — GitHub Actions workflow
- `.github/workflows/Dockerfile.armv6` — Cross-compilation Dockerfile
