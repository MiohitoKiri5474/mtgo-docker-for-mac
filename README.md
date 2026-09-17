# MTGO OCI

Run [Magic: The Gathering Online](https://www.mtgo.com) on **Linux** and **macOS** using Docker.

Pre-built images running MTGO in Docker using [Wine](https://www.winehq.org) are available on Docker Hub, with additional containers for building and running [MTGOSDK](https://github.com/videre-project/MTGOSDK)-based applications.

## Apple Silicon (M-Series Mac) Setup

To run MTGO on Apple Silicon (M1/M2/M3/M4) Macs:

1. Open **Docker Desktop Settings** > **General** (or **Virtualization**).
2. Ensure **"Use Virtualization framework"** and **"Use Rosetta for x86/amd64 emulation on Apple Silicon"** are **enabled**.
3. Under **Settings** > **Resources**, allocate at least **4 CPUs** and **6–8 GB RAM** for Wine and .NET stability.

All Dockerfiles and Compose configurations in this repo are pre-configured to target `linux/amd64` under Rosetta emulation.

---

## Quick Start

Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) (macOS) or [Docker Engine](https://docs.docker.com/engine/install/) (Linux).

> [!TIP]
> **Automatic Installation**: MTGO will automatically download and install on the first run of a new container. You can disable this by setting `AUTO_INSTALL_MTGO=false`. once setup, launch the game with `mtgo`.

Then run the command for your platform:

<details open>
<summary><b>macOS (Headless + VNC) — Recommended for Mac</b></summary>

Runs a virtual desktop inside the container. All windows stay together.
```bash
docker run -it --platform linux/amd64 --name mtgo \
  -e DISPLAY=:99 \
  -e START_VNC=true \
  -e VNC_PASSWORD=yourpassword \
  -p 5901:5900 \
  videreproject/mtgo:headless
```
Then open **Screen Sharing** (⌘+Space → "Screen Sharing") and connect to `vnc://localhost:5901`.

> [!NOTE]
> Host port 5900 conflicts with macOS's built-in Screen Sharing/AirPlay Receiver service. Use 5901 (or any free port) instead.

> [!TIP]
> MTGO's UI is not responsive in headless mode. The resolution is fixed at startup. Use "Scale to Fit" in Screen Sharing to adjust the view, or set a different `RESOLUTION` (see [Configuration](#configuration)).
</details>

<details>
<summary><b>macOS (XQuartz) — High Performance</b></summary>

Lower latency by forwarding windows directly to your desktop.

> [!WARNING]
> Pop-up windows and dialogs may sometimes get stuck behind the main window or lose focus.

1. `brew install --cask xquartz`
2. Open XQuartz → Preferences → Security → Check "Allow connections from network clients."
3. Restart XQuartz, then run `xhost +localhost`.
4. Run:
   ```bash
   docker run -it --platform linux/amd64 --name mtgo-x11 \
     -e DISPLAY=host.docker.internal:0 \
     -v /tmp/.X11-unix:/tmp/.X11-unix \
     videreproject/mtgo:x11
   ```
</details>

<details>
<summary><b>Linux (Wayland)</b></summary>

For modern desktops (GNOME 45+, KDE Plasma 6):
```bash
docker run -it --platform linux/amd64 --name mtgo \
  -e DISPLAY=$DISPLAY \
  -e WAYLAND_DISPLAY=$WAYLAND_DISPLAY \
  -e XDG_RUNTIME_DIR=/tmp/runtime-dir \
  -v ${XDG_RUNTIME_DIR}/wayland-0:/tmp/runtime-dir/wayland-0 \
  videreproject/mtgo:wayland
```
</details>

<details>
<summary><b>Linux (X11)</b></summary>

For X11-based desktops or NVIDIA GPU users:
```bash
xhost +local:docker
docker run -it --platform linux/amd64 --name mtgo \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  videreproject/mtgo:x11
```
</details>

## Persistent Setup (Docker Compose)

The commands above work for quick sessions but **do not persist data** between runs. For regular use, use the Compose files in this repository to automatically manage volumes for your Wine settings, decklists, and login data.

1. Clone this repository or use your fork.
2. Run from the project root:
   ```bash
   # macOS / headless (Recommended)
   docker compose -f mtgo/docker-compose.yml up -d mtgo-headless

   # Development with MTGOSDK (Headless)
   docker compose -f mtgosdk/docker-compose.yml up -d mtgosdk-headless

   # Linux (Wayland)
   docker compose -f mtgosdk/docker-compose.yml up -d mtgosdk-wayland

   # Linux (X11)
   docker compose -f mtgosdk/docker-compose.yml up -d mtgosdk-x11
   ```

## Available Images

| Image | Description |
|-------|-------------|
| `videreproject/mtgo` | MTGO runtime (Wine + .NET 4.8 + fonts) |
| `videreproject/mtgosdk` | Development environment (adds .NET SDK + auto-clones [MTGOSDK](https://github.com/videre-project/MTGOSDK)) |

Both images publish `:headless`, `:x11`, and `:wayland` variants. The `:latest`
tag points at the headless variant. Replace `videreproject/mtgo` with
`videreproject/mtgosdk` in any command above to use the SDK variant.

## Configuration

> [!NOTE]
> These variables primarily control the **Headless** environment. In Wayland/X11 modes, your host desktop manages the display natively.

| Variable | Description | Default |
|----------|-------------|---------|
| `MTGO_HEADLESS` | Overrides variant-based headless detection | `true` for `:headless`, `false` for interactive variants |
| `MTGO_ALSA_NULL` | Routes ALSA to the bundled null sink | `true` for `:headless`, `false` for interactive variants |
| `START_VNC` | Starts the x11vnc server (Headless only) | `false` |
| `VNC_PASSWORD` | Sets the x11vnc connection password (Headless only) | unset (no auth) |
| `WINE_VIRTUAL_DESKTOP` | Enables Wine's "Emulate Virtual Desktop" for window stability (Headless only) | `true` |
| `RESOLUTION` | Sets the Xvfb and Virtual Desktop resolution (Headless only) | `1280x1024x24` |
| `AUTO_INSTALL_MTGO` | Automatically runs `install-mtgo.sh` if MTGO is missing | `true` |
| `MTGOSDK_PATH` | Path to your local [MTGOSDK](https://github.com/videre-project/MTGOSDK) repository | `../../MTGOSDK` |

## Reference

| Action | Command |
|--------|---------|
| Install MTGO | `install-mtgo.sh` |
| Run MTGO | `mtgo` |
| Pull latest image | `docker pull --platform linux/amd64 videreproject/mtgo:latest` |
| Open a shell | `docker exec -it mtgo /bin/bash` |
| Stop | `docker stop mtgo` |
| Remove | `docker rm mtgo` |
| View logs | `docker logs -f mtgo` |



<details>
<summary><b>Building Locally</b></summary>

To modify and rebuild the images yourself (with native Apple Silicon Rosetta support):
```bash
docker compose -f mtgo/docker-compose.yml build
docker compose -f mtgosdk/docker-compose.yml build
```
</details>

## License

This project is licensed under the [Apache-2.0 License](/LICENSE).
