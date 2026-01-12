#!/bin/bash

set -euo pipefail

# Install Python tools via uv
# Requires: uv (installed via dnf)

# Check if uv is available
if ! command -v uv &> /dev/null; then
    echo "ERROR: uv is not installed. Install it via: sudo dnf install uv" >&2
    exit 1
fi

# Install ty (Python type checker / LSP)
if command -v ty &> /dev/null; then
    echo "ty is already installed: $(ty --version)"
else
    echo "Installing ty via uv..."
    uv tool install ty@latest
    echo "ty installed successfully"
fi
