#!/bin/bash
# Define the screenshot directory
SCREENSHOT_DIR="$HOME/Pictures/screenshots"

# Create the directory if it doesn't exist
mkdir -p "$SCREENSHOT_DIR"

# Capture the screenshot and save it with a timestamp to avoid overwriting
# maim -s "$SCREENSHOT_DIR/screenshot_$(date +%Y%m%d_%H%M%S).png"

# Optionally, copy the screenshot to the clipboard
maim -s | xclip -selection clipboard -t image/png
