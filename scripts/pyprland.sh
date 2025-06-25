#!/usr/bin/env bash

#
# Creates a dedicated Python virtual environment for a given program.
#
# Features:
# - Installs to a structured directory (~/dotfiles/pyenvs/<program>/.venv).
# - Cleans up failed installations automatically.
# - Always returns to the original directory.
# - Accepts the program name as an argument (defaults to 'pyprland').
# - Safe to run multiple times; it won't reinstall if the venv exists.
#

# --- Strict Mode ---
# Exit on error, treat unset variables as errors, and fail pipelines on first error.
set -euo pipefail

# --- Configuration ---
# The program to install. Can be overridden by the first command-line argument.
readonly PROGRAM_NAME="${1:-pyprland}"
# Base directory for all Python environments. Using $HOME is more robust than ~.
readonly INSTALL_BASE_DIR="$HOME/dotfiles/pyenvs"
# Full path for the program's installation.
readonly INSTALL_DIR="$INSTALL_BASE_DIR/$PROGRAM_NAME"
readonly VENV_DIR=".venv"

# --- Logging ---
# Simple logger function to prepend timestamps and log levels.
log() {
  echo >&2 "[$(date +'%Y-%m-%d %H:%M:%S')] [$1] $2"
}

# --- Cleanup ---
# This function is triggered on any script exit (normal, error, or interrupt).
cleanup() {
  local exit_code=$? # Capture the script's exit code.
  
  # Ensure we always return to the directory where the script was called.
  # This happens regardless of success or failure.
  cd "$ORIGINAL_DIR"

  # If the CLEANUP_FLAG is set, it means the script failed mid-process.
  if [[ "$CLEANUP_FLAG" == "true" ]]; then
    log "ERROR" "Script exited with code $exit_code. An error occurred."
    log "INFO" "Cleaning up partial installation at '$INSTALL_DIR'..."
    rm -rf "$INSTALL_DIR"
    log "INFO" "Cleanup complete."
  fi
  
  # Finally, exit the script with the original exit code.
  exit $exit_code
}

# --- Main Script Logic ---

# Save the directory the script was called from.
readonly ORIGINAL_DIR=$(pwd)

# Set a flag that will be checked by the cleanup function.
# We'll set this to "true" only after we start creating files/directories.
CLEANUP_FLAG="false"

# Register the `cleanup` function to run on EXIT.
# This trap is the key to ensuring cleanup and `cd`-ing back happens reliably.
trap cleanup EXIT

log "INFO" "Starting setup for program: '$PROGRAM_NAME'."

# 1. Dependency Check
if ! command -v python &>/dev/null; then
  log "ERROR" "'python' command not found. Please ensure Python is installed and in your PATH."
  exit 1
fi

# 2. Idempotency Check
if [ -d "$INSTALL_DIR/$VENV_DIR" ]; then
  log "WARN" "Virtual environment for '$PROGRAM_NAME' already exists at '$INSTALL_DIR/$VENV_DIR'."
  log "INFO" "Nothing to do. Exiting."
  exit 0
fi

# 3. Create Directories
log "INFO" "Creating installation directory: '$INSTALL_DIR'"
mkdir -p "$INSTALL_DIR"

# From this point forward, if anything fails, we want to clean up the directory we just created.
CLEANUP_FLAG="true"

cd "$INSTALL_DIR"
log "INFO" "Changed to directory: '$(pwd)'"

# 4. Create Virtual Environment
log "INFO" "Creating Python virtual environment..."
if ! python -m venv "$VENV_DIR"; then
  log "ERROR" "Failed to create Python virtual environment."
  exit 1 # The trap will handle cleanup and exit.
fi

# 5. Install the Package
log "INFO" "Installing '$PROGRAM_NAME' using pip from the new venv..."
# Calling the venv's pip directly is more robust in scripts than `source activate`.
if ! "$VENV_DIR/bin/pip" install --quiet "$PROGRAM_NAME"; then
  log "ERROR" "Failed to install '$PROGRAM_NAME' via pip."
  exit 1 # The trap will handle cleanup and exit.
fi

# 6. Success
# If we've reached this point, the installation was successful.
# Disable the cleanup flag so the trap doesn't remove our successful installation.
CLEANUP_FLAG="false"

log "INFO" "Successfully installed '$PROGRAM_NAME' in '$INSTALL_DIR'."

# The trap will handle returning to the original directory and exiting with code 0.
