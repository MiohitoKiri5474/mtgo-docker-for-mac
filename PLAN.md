# MTGO Docker Support for Apple Silicon (M-Series Mac) - Implementation Plan

## 1. Executive Summary & Problem Statement

### 1.1 Context
This repository provides containerized environments (Wine + .NET + Xvfb/VNC/Wayland/X11) for running **Magic: The Gathering Online (MTGO)** and building applications with **MTGOSDK** on Linux and macOS.

### 1.2 The Problem
When attempting to build or run containers on Apple Silicon (M1/M2/M3/M4) Macs:
1. **Missing Platform Tags**: Dockerfiles and `docker-compose.yml` lacked explicit `--platform=linux/amd64` directives.
2. **Docker Engine Behavior**: Docker Desktop on Apple Silicon defaults to target `linux/arm64`, triggering build errors when a base image has no `linux/arm64` manifest.
3. **Application Architecture**: MTGO is a legacy Windows x86/x64 application built on .NET Framework 4.8 (WPF) with a ClickOnce bootstrapper. It has no native ARM64 Windows version.
4. **Wine WoW64 crash under Rosetta**: Wine's newer WoW64 architecture (≥10.8) crashes Rosetta 2 when spawning any 32-bit process, breaking MTGO's 32-bit ClickOnce bootstrapper. Resolved by switching `mtgo/Dockerfile` to `debian:bookworm-slim` + classic (non-WoW64) Wine 9.0 from WineHQ's apt repo, which ships a real i386 build alongside amd64.

---

## 2. Technical Strategy: Emulation vs. Native ARM64

| Approach | Description | Pros | Cons | Recommendation |
| :--- | :--- | :--- | :--- | :--- |
| **Option A: `linux/amd64` via Docker + Rosetta 2** | Run `linux/amd64` container with Wine WOW64 using Apple's Rosetta 2 for Linux in Docker Desktop. | • Proven Wine + .NET 4.8 compatibility.<br>• Near-native execution speed with Rosetta 2.<br>• Minimal code changes required. | • Requires Rosetta 2 enabled in Docker Desktop. | **Primary / Recommended** |
| **Option B: Native `linux/arm64` + Box64 / FEX-Emu** | Run `linux/arm64` container with Box64/FEX-Emu user-space translation + Wine. | • No x86 VM kernel emulation needed. | • .NET Framework 4.8 WPF frequently fails to install or crashes.<br>• Extremely fragile setup and maintenance. | Not Recommended |

---

## 3. Architecture Overview

```mermaid
flowchart TD
    subgraph Host["macOS (Apple Silicon M-Series)"]
        DockerDesktop["Docker Desktop (Virtualization Framework)"]
        Rosetta["Rosetta 2 for Linux (x86_64 Emulation)"]
        ScreenShare["Screen Sharing App (vnc://localhost:5900)"]
    end

    subgraph Container["mtgo Container (linux/amd64)"]
        Wine["Wine 9.0 (classic, non-WoW64)"]
        DotNet["Wine .NET Framework 4.8 + Fonts (GDI/WPF)"]
        MTGO["MTGO Client (ClickOnce / setup.exe)"]
        Xvfb["Xvfb (Virtual Display :99)"]
        VNC["x11vnc (:5900)"]
    end

    subgraph SDKContainer["mtgosdk Container (linux/amd64)"]
        LinuxDotNet[".NET 10 Linux SDK"]
        WinDotNet[".NET 10 Windows SDK (C:\\dotnet)"]
        MTGOSDKCode["MTGOSDK C# Source"]
    end

    DockerDesktop --> Rosetta
    Rosetta --> Container
    Rosetta --> SDKContainer
    Xvfb --> VNC
    ScreenShare -->|Port 5900| VNC
    Wine --> DotNet --> MTGO
```

---

## 4. Repository Audit & Required Changes

### 4.1 `mtgo/Dockerfile` — done
- [x] Base switched to `debian:bookworm-slim` with explicit `--platform=linux/amd64` and classic Wine 9.0 (see §1.2.4), avoiding the WoW64 Rosetta crash entirely.
- [x] winetricks (`corefonts`, `gdiplus`, fonts, win7 mode) installs reliably under Rosetta via `xvfb-run`.

### 4.2 `mtgosdk/Dockerfile` — done
- [x] `ARG BASE_IMAGE` resolves through `mtgo-runtime`, itself pinned to `--platform=linux/amd64`.
- [x] `dotnet-install.sh` targets `linux-x64` under Rosetta.

### 4.3 `common.yml` — done
- [x] `platform: linux/amd64` set on `x11-base`, `wayland-base`, `headless-base`.

### 4.4 `mtgo/docker-compose.yml` & `mtgosdk/docker-compose.yml` — done
- [x] `platform: linux/amd64` on all service definitions.
- [x] Host VNC ports split to `5901`/`5902` defaults to avoid conflicting with macOS's own port 5900 (Screen Sharing/AirPlay).

### 4.5 `.github/workflows/publish.yml` — done
- [x] buildx workflow specifies `platforms: linux/amd64`.

### 4.6 `README.md` — done
- [x] Apple Silicon (M-Series Mac) setup section added.
- [x] `docker run` quick-start examples use `--platform linux/amd64` and host port `5901`.
- [x] `VNC_PASSWORD` documented in the configuration table.

---

## 5. Step-by-Step Implementation Plan

### Phase 1: Platform & Configuration Updates
1. Edit `mtgo/Dockerfile` and `mtgosdk/Dockerfile` to include `--platform=linux/amd64`.
2. Edit `common.yml`, `mtgo/docker-compose.yml`, and `mtgosdk/docker-compose.yml` to specify `platform: linux/amd64`.
3. Update `.github/workflows/publish.yml` with `platforms: linux/amd64`.

### Phase 2: Local Host Environment Verification
1. Verify Docker Desktop settings:
   - **General** > **Use Virtualization framework**: Checked.
   - **General** > **Use Rosetta for x86/amd64 emulation on Apple Silicon**: Checked.
   - **Resources** > **Memory**: Allocate at least 6 GB (8 GB recommended).
   - **Resources** > **CPUs**: Allocate at least 4 cores.

### Phase 3: Build & Baseline Testing
1. Build `mtgo-headless` locally:
   ```bash
   docker compose -f mtgo/docker-compose.yml build mtgo-headless
   ```
2. Start the headless container:
   ```bash
   docker compose -f mtgo/docker-compose.yml up -d mtgo-headless
   ```
3. Run environment diagnostics inside the container:
   ```bash
   docker exec -it mtgo-headless /usr/local/bin/check-env.sh
   ```

### Phase 4: MTGO Client & VNC Display Testing
1. Connect via macOS Screen Sharing:
   - Press `Cmd + Space` -> type `Screen Sharing`.
   - Connect to `vnc://localhost:5900`.
2. Trigger MTGO installation inside the container:
   ```bash
   docker exec -it mtgo-headless install-mtgo.sh
   ```
3. Verify MTGO launches and displays correctly on the virtual desktop:
   ```bash
   docker exec -it mtgo-headless mtgo
   ```

### Phase 5: MTGOSDK Build & Run Testing
1. Build `mtgosdk-headless`:
   ```bash
   docker compose -f mtgosdk/docker-compose.yml build mtgosdk-headless
   ```
2. Start the container and verify `wine-run` / `wine-shell` commands.

### Phase 6: Documentation & Final Polish
1. Update `README.md` with Apple Silicon instructions and troubleshooting tips.
2. Commit all changes to the repository.

---

## 6. Troubleshooting & Best Practices for Apple Silicon

- **Slow build during `winetricks dotnet48`**:
  Installing .NET 4.8 in Wine under emulation requires substantial CPU and disk I/O. Ensure Rosetta is active (not QEMU) and Docker has at least 6 GB of RAM assigned.
- **Display Resolution**:
  By default, `RESOLUTION=1280x1024x24`. If the MTGO window feels cramped, set `RESOLUTION=1920x1080x24` in `docker-compose.yml` or the `docker run` command.
- **Audio Crashes**:
  `xvfb-entrypoint.sh` automatically configures `WINE_AUDIO_DRIVER=pulse` or null ALSA to prevent MTGO's WPF audio engine from crashing when no physical sound device is present.
