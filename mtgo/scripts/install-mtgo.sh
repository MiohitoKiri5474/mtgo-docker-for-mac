#!/bin/bash
set -e

SETUP_EXE="/home/wine/mtgo_setup.exe"

# The image bakes this download in at build time; only fetch it if missing
# (e.g. an older image, or the file was removed).
if [ ! -f "$SETUP_EXE" ]; then
    echo "Downloading MTGO installer..."
    wget -O "$SETUP_EXE" https://mtgo.patch.daybreakgames.com/patch/mtg/live/client/setup.exe
fi

# Run installer
echo "Running MTGO installer..."
wine "$SETUP_EXE"

echo "Installation complete. You can now run 'mtgo' to launch the game."
