#!/bin/bash
set -e

echo "Installing Python dependencies..."
pip install -r requirements.txt

echo "Downloading CCExtractor prebuilt binary..."
wget -q https://github.com/CCExtractor/ccextractor/releases/download/v0.94/ccextractor.linux -O /usr/local/bin/ccextractor
chmod +x /usr/local/bin/ccextractor

echo "Verifying CCExtractor..."
ccextractor --version

echo "Build complete!"