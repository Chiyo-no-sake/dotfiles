#!/bin/bash
# appimage_downloader.sh

# The directory where AppImages will be downloaded.
# Ensure this directory exists or can be created by the script.
APPIMAGES_DL_DIR="$HOME/dotfiles/appimages"

# A list of AppImage download entries in the format "URL FILENAME"
# The FILENAME will be appended to APPIMAGES_DL_DIR to form the final path.
# IMPORTANT: Use direct download links for AppImages.
APPIMAGES_LIST=(
    "https://downloads.cursor.com/production/53b99ce608cba35127ae3a050c1738a959750865/linux/x64/Cursor-1.0.0-x86_64.AppImage Cursor.AppImage"
)

# Enable strict mode for robustness:
set -euo pipefail

# --- Global Variables ---
# Suffix for the hidden URL tracking file (e.g., .dbeaver.AppImage.url)
readonly URL_TRACKING_SUFFIX=".url"
APP_TO_UPDATE="" # Stores the filename of the AppImage to force update
APP_FOUND_IN_LIST=false # Flag to check if APP_TO_UPDATE was found

# --- Helper Functions ---
log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_error() {
    echo "[ERROR] $1" >&2 # Output to standard error
}

# --- Cleanup Function for Interruptions ---
# This function is called when SIGINT (Ctrl+C) is received.
cleanup() {
    log_info "Interruption detected. Performing cleanup..."
    # Iterate through the APPIMAGES_LIST to find and remove any potential temporary files
    for entry in "${APPIMAGES_LIST[@]}"; do
        read -r _ filename <<< "$entry"
        local_appimage_path="${APPIMAGES_DL_DIR}/${filename}"
        temp_download_path="${local_appimage_path}.part"
        local_url_tracker_path="${APPIMAGES_DL_DIR}/.${filename}${URL_TRACKING_SUFFIX}"
        local_temp_url_tracker_path="${local_url_tracker_path}.tmp"

        if [[ -f "$temp_download_path" ]]; then
            log_info "Removing partial AppImage download: '${temp_download_path}'"
            rm -f "$temp_download_path"
        fi
        if [[ -f "$local_temp_url_tracker_path" ]]; then
            log_info "Removing partial URL tracker: '${local_temp_url_tracker_path}'"
            rm -f "$local_temp_url_tracker_path"
        fi
    done
    log_info "Cleanup complete. Exiting."
    exit 1 # Exit with a non-zero status to indicate abnormal termination
}

# Set the trap: call 'cleanup' function if SIGINT (Ctrl+C) is received
trap cleanup SIGINT

# --- Argument Parsing ---
parse_arguments() {
    if [[ "$#" -gt 0 ]]; then
        case "$1" in
            "update")
                if [[ -n "$2" ]]; then
                    APP_TO_UPDATE="$2"
                    log_info "Force updating only: '${APP_TO_UPDATE}'"
                else
                    log_error "Usage: $0 update <appimage_filename>"
                    log_error "Example: $0 update dbeaver.AppImage"
                    exit 1
                fi
                ;;
            *)
                log_error "Unknown command: '$1'"
                log_error "Usage: $0 [update <appimage_filename>]"
                exit 1
                ;;
        esac
    fi
}

# Parse command-line arguments
parse_arguments "$@"

# --- Pre-checks ---
# Check if wget is available
if ! command -v wget &> /dev/null; then
    log_error "wget could not be found. Please install wget to use this script (e.g., sudo apt install wget or sudo yum install wget)."
    exit 1
fi

# Create the download directory if it doesn't exist
log_info "Ensuring download directory exists: ${APPIMAGES_DL_DIR}"
mkdir -p "$APPIMAGES_DL_DIR" || {
    log_error "Failed to create directory: ${APPIMAGES_DL_DIR}. Check permissions or path."
    exit 1
}

# --- Main Download Loop ---
for entry in "${APPIMAGES_LIST[@]}"; do
    # Read the URL and filename from the current list entry
    read -r url filename <<< "$entry"

    local_appimage_path="${APPIMAGES_DL_DIR}/${filename}"
    local_url_tracker_path="${APPIMAGES_DL_DIR}/.${filename}${URL_TRACKING_SUFFIX}"
    temp_download_path="${local_appimage_path}.part" # Temporary file for atomic AppImage download
    local_temp_url_tracker_path="${local_url_tracker_path}.tmp" # Temporary file for atomic URL tracking

    should_download=false
    reason=""

    # Check if a specific app is requested for update
    if [[ -n "$APP_TO_UPDATE" ]]; then
        if [[ "$filename" == "$APP_TO_UPDATE" ]]; then
            should_download=true
            reason="Force update requested for '${filename}'."
            APP_FOUND_IN_LIST=true # Mark that the requested app was found
        else
            # If a specific app is requested, but this is not it, skip this iteration.
            continue
        fi
    fi

    # If not specifically forced, check existing file and URL
    if ! $should_download; then # Only proceed with these checks if not already marked for forced download
        if [[ -f "$local_appimage_path" && -f "$local_url_tracker_path" ]]; then
            old_url=$(<"$local_url_tracker_path") # Read content of tracking file
            if [[ "$url" == "$old_url" ]]; then
                log_info "'${filename}' is already up-to-date (URL unchanged)."
                continue # Skip this download
            else
                should_download=true
                reason="URL for '${filename}' has changed. Updating."
            fi
        else
            should_download=true
            if [[ ! -f "$local_appimage_path" ]]; then
                reason="'${filename}' not found locally. Downloading."
            else # AppImage exists, but .url tracking file doesn't
                reason="URL tracking file for '${filename}' not found. Re-downloading to ensure tracking."
            fi
        fi
    fi

    # Perform download if should_download is true
    if $should_download; then
        log_info "${reason} Attempting to download '${filename}' from '${url}' to temporary file '${temp_download_path}'."

        # Download the AppImage to a temporary file
        if wget --show-progress -O "$temp_download_path" "$url"; then
            log_success "Downloaded '${filename}' successfully to temporary location."

            # Move the temporary AppImage file to its final destination (atomic)
            if mv "$temp_download_path" "$local_appimage_path"; then
                log_success "Moved '${filename}' to final location: '${local_appimage_path}'"

                # Make the downloaded AppImage executable
                if chmod +x "$local_appimage_path"; then
                    log_info "Made '${filename}' executable."

                    # Atomically save the URL to the tracking file
                    # Write to a temporary .url file first
                    if echo "$url" > "$local_temp_url_tracker_path"; then
                        # Then atomically move it to the final .url path
                        if mv "$local_temp_url_tracker_path" "$local_url_tracker_path"; then
                            log_info "Saved URL for '${filename}'."
                        else
                            log_error "Failed to move temporary URL tracker '${local_temp_url_tracker_path}' to '${local_url_tracker_path}'. AppImage downloaded and executable, but tracking might be incomplete."
                            log_error "Removing '${local_appimage_path}' to avoid inconsistent state due to failed URL tracking."
                            rm -f "$local_appimage_path" # Remove the AppImage if tracking fails
                        fi
                    else
                        log_error "Failed to write temporary URL tracker '${local_temp_url_tracker_path}'. AppImage downloaded and executable, but tracking might be incomplete."
                        log_error "Removing '${local_appimage_path}' to avoid inconsistent state due to failed URL tracking."
                        rm -f "$local_appimage_path" # Remove the AppImage if writing the temp URL file fails
                    fi
                else
                    log_error "Failed to make '${filename}' executable at '${local_appimage_path}'. Permissions issue?"
                    log_error "Removing partially processed AppImage: '${local_appimage_path}'."
                    rm -f "$local_appimage_path" # Remove the file if it can't be made executable.
                    # Do NOT write the .url file, as the AppImage isn't fully ready.
                fi
            else
                log_error "Failed to move temporary file '${temp_download_path}' to '${local_appimage_path}'. Disk issue or permissions?"
                rm -f "$temp_download_path" # Clean up temp file
                # Do NOT touch the existing local_appimage_path or local_url_tracker_path if they exist.
            fi
        else
            log_error "Failed to download '${filename}' from '${url}'. Check URL, network connection, or disk space."
            # The 'trap cleanup' function will handle removal of "$temp_download_path" if Ctrl+C was pressed.
            # If wget failed for another reason (e.g., 404), set -e will exit, and trap will clean up.
            # If set -e did not exit (e.g. wget returned 0 on some weird error), we ensure cleanup here.
            if [[ -f "$temp_download_path" ]]; then
                log_info "Removing incomplete temporary file: '${temp_download_path}'"
                rm -f "$temp_download_path"
            fi
            # Do NOT touch the existing local_appimage_path or local_url_tracker_path if they exist.
        fi
    fi
    echo # Add a newline for better readability between entries
done

# Check if a specific app was requested but not found in the list
if [[ -n "$APP_TO_UPDATE" && "$APP_FOUND_IN_LIST" = false ]]; then
    log_error "AppImage '${APP_TO_UPDATE}' was requested for update but not found in APPIMAGES_LIST."
    exit 1
fi

log_info "AppImage download process completed."
