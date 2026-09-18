FROM --platform=linux/amd64 debian:bookworm-slim

ARG MTGO_VARIANT=headless
# Pinned below the point where upstream Wine made the new WoW64 architecture
# mandatory (~10.8). That architecture crashes Rosetta 2 (Docker Desktop's
# amd64 emulation on Apple Silicon) when spawning any 32-bit process, which
# breaks MTGO's 32-bit ClickOnce bootstrapper entirely. Classic Wine, with a
# real i386 build alongside the amd64 one, does not hit this bug.
ARG WINE_VERSION=9.0.0.0~bookworm-1

USER root

# Classic (non-WoW64) Wine via WineHQ's apt repo: a real 32-bit build plus a
# real 64-bit build, not Wine's newer single-process 32/64 emulation.
RUN dpkg --add-architecture i386 \
    && apt-get update && apt-get install -y --no-install-recommends \
       wget ca-certificates gnupg \
    && mkdir -pm755 /etc/apt/keyrings \
    && wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key \
    && wget -qNP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources \
    && apt-get update \
    && apt-get install -y --install-recommends \
       winehq-stable=${WINE_VERSION} \
       wine-stable=${WINE_VERSION} \
       wine-stable-amd64=${WINE_VERSION} \
       wine-stable-i386:i386=${WINE_VERSION} \
    && apt-mark hold winehq-stable wine-stable wine-stable-amd64 wine-stable-i386:i386 \
    && rm -rf /var/lib/apt/lists/*

# Install basic dependencies and headless tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    xvfb \
    xauth \
    x11vnc \
    procps \
    net-tools \
    x11-utils \
    unzip \
    p7zip-full \
    cabextract \
    && rm -rf /var/lib/apt/lists/*

# winetricks isn't packaged for Debian bookworm; install the upstream script directly.
RUN wget -qO /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
    && chmod +x /usr/local/bin/winetricks

# Fix X11 socket permissions for non-root users
RUN mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix

# Create wine user
ENV WINE_USER wine
ENV WINE_UID 1000
RUN useradd -u $WINE_UID -d /home/wine -m -s /bin/bash $WINE_USER

# wine/wineboot/winecfg etc. are already on the default PATH via /usr/bin.
ENV WINEPREFIX=/home/wine/.wine
ENV WINEARCH=win64
ENV WINEDEBUG=-all
ENV MTGO_VARIANT=${MTGO_VARIANT}
ENV DOTNET_ROOT=C:\\dotnet
WORKDIR /home/wine

# Copy scripts and runtime configuration
USER root
COPY scripts/ /usr/local/bin/
RUN mkdir -p /usr/local/share/mtgo
COPY config/asound-null.conf /usr/local/share/mtgo/asound-null.conf
RUN chmod +x /usr/local/bin/*.sh \
    && ln -s /usr/local/bin/mtgo.sh /usr/local/bin/mtgo
USER wine

# Initialize Wine and install dependencies.
# We need corefonts/gdiplus and Windows 7 mode for MTGO UI and rendering.
# ShowCrashDialog=0 stops a non-interactive winedbg hang if any installer
# step throws (observed with the .NET installer family under Wine).
#
# .NET 4.7.2 (winetricks dotnet472) is deliberately NOT installed here: its
# dependency chain (dotnet40 -> 45 -> 46 -> 461 -> 462 -> 472) hits a Rosetta 2
# bug in the dotnet40 stage's 32-bit bootstrap ("rosetta error: invalid gdt
# selector index 5" -> unhandled illegal instruction), which then hangs
# forever because winedbg attaches on the crash and waits on stdin. This is a
# Rosetta emulation gap (32-bit segment-selector handling), not something
# fixable from the Dockerfile. Install .NET manually over VNC if MTGO prompts
# for it, or via install-mtgo.sh.
RUN WINEDLLOVERRIDES="mscoree,mshtml=" xvfb-run -a wineboot --init \
    && wineserver -w \
    && wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\WineDbg" /v ShowCrashDialog /t REG_DWORD /d 0 /f \
    && xvfb-run -a winetricks -q corefonts calibri tahoma consolas lucida win7 gdiplus renderer=gdi \
    && wineserver -w \
    && rm -rf /home/wine/.cache/winetricks

# Bake the MTGO bootstrapper download into the image so first-run doesn't pay
# for it. This is as far as "install at build time" goes: WINEPREFIX
# (/home/wine/.wine) is a runtime volume mount, and the ClickOnce bootstrapper
# re-validates against the patch server on every launch anyway, so running the
# installer here wouldn't survive or save anything.
RUN wget -O /home/wine/mtgo_setup.exe https://mtgo.patch.daybreakgames.com/patch/mtg/live/client/setup.exe

# Set up workspace directory
USER root
RUN mkdir -p /workspace && chown wine:wine /workspace
USER wine
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/xvfb-entrypoint.sh"]
CMD ["/bin/bash"]
