#!/bin/bash

asdf --version
asdf_error=$?

# Configuration
# IMPORTANT: Replace this with the actual URL of the ASDF tar.gz release.
ASDF_RELEASE_DL_URL="https://github.com/asdf-vm/asdf/releases/download/v0.18.0/asdf-v0.18.0-linux-amd64.tar.gz"

TARGET_DIR="$HOME/dotfiles/.local/share/bin"
BINARY_NAME="asdf"
TAR_GZ_FILENAME=$(basename "$ASDF_RELEASE_DL_URL" | sed 's/\?.*//') # Handles URLs with query parameters

# --- Error Handling & Atomicity Setup ---

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# The return value of a pipeline is the status of the last command to exit with a non-zero status,
# or zero if all commands in the pipeline exit successfully.
set -o pipefail

TEMP_DIR="" # Initialize to ensure it's set for the trap function

# Trap function to ensure cleanup even on script exit (success or failure)
cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        echo "Cleaning up temporary directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi
}

# Register the cleanup function to be called on EXIT (normal or error)
trap cleanup EXIT
asdf="$TARGET_DIR/$BINARY_NAME"

# only if asdf is not installed yet
if [[ $asdf_error -ne 0 ]]; then
  # --- Main Logic ---

  echo "Starting ASDF binary installation..."

  # 1. Validate the download URL
  if [[ "$ASDF_RELEASE_DL_URL" == "YOUR_ASDF_DOWNLOAD_URL_HERE" ]]; then
      echo "ERROR: Please update 'ASDF_RELEASE_DL_URL' in the script with the actual download link." >&2
      exit 1
  fi

  # 2. Create a unique temporary directory
  echo "Creating temporary directory..."
  TEMP_DIR=$(mktemp -d) || { echo "ERROR: Failed to create temporary directory." >&2; exit 1; }
  echo "Temporary directory created at: $TEMP_DIR"

  # Change to the temporary directory. This simplifies download and extraction paths.
  cd "$TEMP_DIR" || { echo "ERROR: Failed to change to temporary directory: $TEMP_DIR" >&2; exit 1; }

  # 3. Download the tar.gz file
  echo "Downloading '$TAR_GZ_FILENAME' from '$ASDF_RELEASE_DL_URL'..."
  # -f: Fail silently (no HTML output on HTTP errors)
  # -L: Follow redirects
  # -O: Write output to a local file named like the remote file
  curl -fLO "$ASDF_RELEASE_DL_URL" || { echo "ERROR: Failed to download '$TAR_GZ_FILENAME'." >&2; exit 1; }
  echo "Download complete."

  # 4. Extract the tar.gz file
  echo "Extracting '$TAR_GZ_FILENAME'..."
  # -x: Extract
  # -z: Filter the archive through gzip
  # -f: Use archive file
  tar -xzf "$TAR_GZ_FILENAME" || { echo "ERROR: Failed to extract '$TAR_GZ_FILENAME'." >&2; exit 1; }
  echo "Extraction complete."

  # 5. Find the 'asdf' binary within the extracted content.
  # Instead of assuming a specific root directory, we'll search for the binary directly.
  ASDF_BINARY_PATH=$(find . -type f -name "$BINARY_NAME" -print -quit)

  if [[ -z "$ASDF_BINARY_PATH" ]]; then
      echo "ERROR: Expected binary '$BINARY_NAME' not found anywhere in the extracted content." >&2
      echo "Please check the structure of the downloaded archive or the ASDF_RELEASE_DL_URL." >&2
      exit 1
  fi

  # Sanity check: Ensure it's not a directory and is a regular file.
  if [[ ! -f "$ASDF_BINARY_PATH" ]]; then
      echo "ERROR: Found a path '$ASDF_BINARY_PATH' named '$BINARY_NAME', but it's not a regular file." >&2
      exit 1
  fi

  echo "Binary '$BINARY_NAME' found at '$ASDF_BINARY_PATH'."

  # 6. Ensure the target directory exists
  echo "Ensuring target directory exists: $TARGET_DIR"
  mkdir -p "$TARGET_DIR" || { echo "ERROR: Failed to create target directory '$TARGET_DIR'." >&2; exit 1; }

  # 7. Move the binary to the target directory
  echo "Moving '$ASDF_BINARY_PATH' to '$TARGET_DIR/'..."
  mv "$ASDF_BINARY_PATH" "$TARGET_DIR/" || { echo "ERROR: Failed to move '$ASDF_BINARY_PATH' to '$TARGET_DIR/'." >&2; exit 1; }
  echo "Binary moved successfully."

  # 8. Set execute permissions
  echo "Setting execute permissions for '$TARGET_DIR/$BINARY_NAME'..."
  chmod +x "$TARGET_DIR/$BINARY_NAME" || { echo "ERROR: Failed to set execute permissions for '$TARGET_DIR/$BINARY_NAME'." >&2; exit 1; }
  echo "Execute permissions set."

  echo "ASDF binary installation completed successfully!"
fi

echo "Installing add-ons..."
$asdf plugin add python https://github.com/asdf-community/asdf-python.git
$asdf install python 3.13.5
$asdf install python 3.11.13

$asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
$asdf install nodejs 22.16.0

$asdf plugin add java https://github.com/halcyon/asdf-java.git
$asdf install java openjdk-24.0.1

$asdf plugin add lazydocker https://github.com/comdotlinux/asdf-lazydocker.git
$asdf install lazydocker latest

# set defaults
$asdf set -u nodejs 22.16.0
$asdf set -u python 3.11.13
$asdf set -u java openjdk-24.0.1
$asdf set -u lazydocker latest

# npm global packages
sudo npm i -g neovim
