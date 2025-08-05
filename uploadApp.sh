#!/bin/bash

# Source and destination folders
SOURCE="/Users/interngest/app/test_app/"
DEST="/Users/interngest/Library/CloudStorage/GoogleDrive-creative.tnsweb+2@tnsgrp.com/.shortcut-targets-by-id/13M_PNOCEdXhH_ytimFp1hMK-j1lH_N2J/2025_インターン/app/test_app/"

# Create destination if it doesn't exist
mkdir -p "$DEST"

# Copy contents using rsync
rsync -avh --progress "$SOURCE" "$DEST"
