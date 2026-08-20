#!/bin/bash
set -e

# Disable Wine logging and set .NET runtime path
export PATH="/opt/wine/bin:${PATH}"
export WINEDEBUG="${WINEDEBUG:--all}"
export DOTNET_ROOT="${DOTNET_ROOT:-C:\\dotnet}"

# Configuration
X_DISPLAY=${DISPLAY:-:99}
RESOLUTION=${RESOLUTION:-1280x1024x24}
MTGO_VARIANT=${MTGO_VARIANT:-}

is_truthy() {
    case "${1,,}" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

is_falsey() {
    case "${1,,}" in
        0|false|no|off) return 0 ;;
        *) return 1 ;;
    esac
}

is_headless_mode() {
    if [ -n "${MTGO_HEADLESS:-}" ]; then
        is_truthy "$MTGO_HEADLESS" && return 0
        is_falsey "$MTGO_HEADLESS" && return 1
    fi

    if [ "$MTGO_VARIANT" = "headless" ]; then
        return 0
    fi

    # Backward compatibility for older images and compose files that only set
    # DISPLAY=:99 to request the virtual display.
    if [ -z "$MTGO_VARIANT" ] && [ "$X_DISPLAY" = ":99" ]; then
        return 0
    fi

    return 1
}

configure_headless_audio() {
    export WINE_AUDIO_DRIVER="${WINE_AUDIO_DRIVER:-pulse}"

    # MTGO's WPF audio manager queries Windows Core Audio's ISimpleAudioVolume.
    # The headless ALSA driver can expose a partial COM surface under Wine, which
    # crashes MTGO during startup. The pulse driver avoids that broken path even
    # when there is no real audio device attached.
    if command -v wine >/dev/null 2>&1; then
        wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Drivers" \
            /v "Audio" /t REG_SZ /d "$WINE_AUDIO_DRIVER" /f >/dev/null 2>&1 || true
        wineserver -k >/dev/null 2>&1 || true
    fi
}

use_null_alsa() {
    if [ -n "${MTGO_ALSA_NULL:-}" ]; then
        is_truthy "$MTGO_ALSA_NULL" && return 0
        is_falsey "$MTGO_ALSA_NULL" && return 1
    fi

    # The headless variant defaults to null ALSA. Interactive variants leave host
    # audio alone unless explicitly opted in with MTGO_ALSA_NULL=true.
    [ "$HEADLESS_MODE" = "true" ]
}

HEADLESS_MODE=false
if is_headless_mode; then
    HEADLESS_MODE=true
    configure_headless_audio
fi

if use_null_alsa; then
    export ALSA_CONFIG_PATH="${ALSA_CONFIG_PATH:-/usr/local/share/mtgo/asound-null.conf}"
    export ALSA_LOG_LEVEL="${ALSA_LOG_LEVEL:-0}"
fi

# Only start Xvfb if we are on display :99 (default headless)
if [ "$HEADLESS_MODE" = "true" ] && [ "$X_DISPLAY" = ":99" ]; then
    # cleanup stale lock files
    rm -f /tmp/.X${X_DISPLAY#:}*

    echo "Starting Xvfb on display $X_DISPLAY with resolution $RESOLUTION"
    if [ "$DEBUG" = "true" ]; then
        Xvfb $X_DISPLAY -screen 0 $RESOLUTION > /tmp/xvfb.log 2>&1 &
    else
        Xvfb $X_DISPLAY -screen 0 $RESOLUTION &
    fi
    XVFB_PID=$!

    # Wait for Xvfb to start
    for i in {1..50}; do
        if xdpyinfo -display $X_DISPLAY >/dev/null 2>&1; then
            echo "Xvfb is ready."
            break
        fi
        sleep 0.1
    done

    # Start VNC if requested
    if [ "$START_VNC" = "true" ]; then
        echo "Starting x11vnc..."
        VNC_AUTH_OPTS="-nopw"
        if [ -n "$VNC_PASSWORD" ]; then
            VNC_AUTH_OPTS="-passwd $VNC_PASSWORD"
        fi
        if [ "$DEBUG" = "true" ]; then
            x11vnc -display $X_DISPLAY -forever -shared $VNC_AUTH_OPTS -bg -xkb -rfbport 5900 > /tmp/x11vnc.log 2>&1
        else
            x11vnc -display $X_DISPLAY -forever -shared $VNC_AUTH_OPTS -bg -xkb -rfbport 5900
        fi
    fi

    # Enable Wine Virtual Desktop for better window management if requested (default: true for headless)
    WINE_VIRTUAL_DESKTOP=${WINE_VIRTUAL_DESKTOP:-true}
    if [ "$WINE_VIRTUAL_DESKTOP" = "true" ]; then
        echo "Enabling Wine Virtual Desktop (Resolution: ${RESOLUTION%x*})"
        wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Explorer" /v "Desktop" /t REG_SZ /d "Default" /f >/dev/null 2>&1
        wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\Explorer\\Desktops" /v "Default" /t REG_SZ /d "${RESOLUTION%x*}" /f >/dev/null 2>&1
    fi

    # Disable automatic winedbg on crash to prevent orphan processes
    wine reg add "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\AeDebug" /v "Auto" /t REG_SZ /d "0" /f >/dev/null 2>&1

    # Trap signals for cleanup
    trap "kill $XVFB_PID" SIGINT SIGTERM
fi

export DISPLAY="$X_DISPLAY"

# Execute the passed command
exec "$@"
