FROM --platform=linux/amd64 panard/wine:11.2-wow64

ARG MTGO_VARIANT=headless

USER root

# Install basic dependencies and headless tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    curl \
    git \
    gnupg \
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

# Fix X11 socket permissions for non-root users
RUN mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix

# Create wine user
ENV WINE_USER wine
ENV WINE_UID 1000
RUN useradd -u $WINE_UID -d /home/wine -m -s /bin/bash $WINE_USER

# Switch back to wine user for wine operations
ENV PATH="/opt/wine/bin:${PATH}"
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

# Initialize Wine and install dependencies
# We need dotnet48 for MTGO, and corefonts/gdiplus for UI/rendering
RUN xvfb-run -a wineboot --init \
    && wineserver -w \
    && mkdir -p /home/wine/.wine/drive_c/windows/syswow64 /home/wine/.wine/drive_c/windows/system32 \
    && cp -f /home/wine/.wine/drive_c/windows/regedit.exe /home/wine/.wine/drive_c/windows/syswow64/regedit.exe \
    && cp -f /home/wine/.wine/drive_c/windows/regedit.exe /home/wine/.wine/drive_c/windows/system32/regedit.exe \
    && xvfb-run -a winetricks -q dotnet48 corefonts calibri tahoma consolas lucida win7 gdiplus renderer=gdi \
    && wineserver -w \
    && rm -rf /home/wine/.cache/winetricks

# Set up workspace directory
USER root
RUN mkdir -p /workspace && chown wine:wine /workspace
USER wine
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/xvfb-entrypoint.sh"]
CMD ["/bin/bash"]
