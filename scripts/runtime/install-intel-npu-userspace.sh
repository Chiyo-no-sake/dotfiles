#!/usr/bin/env bash

set -euo pipefail

VERSION="1.35.0"
BUILD="20260722-29947505341"
ARCHIVE="linux-npu-driver-v${VERSION}.${BUILD}-ubuntu2404.tar.gz"
URL="https://github.com/intel/linux-npu-driver/releases/download/v${VERSION}/${ARCHIVE}"
ARCHIVE_SHA256="398343e53fdac6023ad0856ef88bb6011b1e12447a112be55e85e27ef7f96c66"
CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/intel-npu-driver/${VERSION}"
EXTRACT_DIR="${CACHE_DIR}/extracted"
INSTALL_DIR="/usr/lib64"
BACKUP_DIR="/usr/local/lib64/intel-npu-backup-before-${VERSION}-usr-lib64"

usage() {
    cat <<EOF
Usage: $0 [install|rollback|verify]

  install   Install Intel NPU UMD/compiler ${VERSION} in ${INSTALL_DIR}
  rollback  Restore the pre-${VERSION} symlinks and remove ${VERSION} files
  verify    Print the NPU device and compiler versions through OpenVINO
EOF
}

verify() {
    local python_bin="${HOME}/repos/hyprwhspr/.venv-npu/bin/python"
    if [[ ! -x "${python_bin}" ]]; then
        python_bin="$(command -v python3)"
    fi

    "${python_bin}" - <<'PY'
import openvino as ov

core = ov.Core()
print("OpenVINO devices:", core.available_devices)
if "NPU" not in core.available_devices:
    raise SystemExit("NPU is not visible to OpenVINO")
print("NPU device:", core.get_property("NPU", "FULL_DEVICE_NAME"))
print("NPU driver version:", core.get_property("NPU", "NPU_DRIVER_VERSION"))
compiler = core.get_property("NPU", "NPU_COMPILER_VERSION")
print("NPU compiler version:", compiler)
if not compiler:
    raise SystemExit("NPU compiler version is 0")
PY
}

extract_deb() {
    local deb="$1"
    local work="$2"
    mkdir -p "${work}"
    ar p "${deb}" data.tar.gz | tar -xzf - -C "${work}"
}

install_driver() {
    mkdir -p "${CACHE_DIR}"
    if [[ ! -f "${CACHE_DIR}/${ARCHIVE}" ]]; then
        curl -fL "${URL}" -o "${CACHE_DIR}/${ARCHIVE}"
    fi

    printf '%s  %s\n' "${ARCHIVE_SHA256}" "${CACHE_DIR}/${ARCHIVE}" | sha256sum -c -

    rm -rf "${EXTRACT_DIR}"
    mkdir -p "${EXTRACT_DIR}/archive" "${EXTRACT_DIR}/root"
    tar -xzf "${CACHE_DIR}/${ARCHIVE}" -C "${EXTRACT_DIR}/archive"

    extract_deb \
        "${EXTRACT_DIR}/archive/intel-level-zero-npu_${VERSION}.${BUILD}~ubuntu24.04_amd64.deb" \
        "${EXTRACT_DIR}/root"
    extract_deb \
        "${EXTRACT_DIR}/archive/intel-driver-compiler-npu_${VERSION}.${BUILD}~ubuntu24.04_amd64.deb" \
        "${EXTRACT_DIR}/root"

    local source_dir="${EXTRACT_DIR}/root/usr/lib/x86_64-linux-gnu"
    for library in \
        libze_intel_npu.so.${VERSION} \
        libopenvino_intel_npu_compiler.so \
        libopenvino_intel_npu_compiler_loader.so; do
        [[ -f "${source_dir}/${library}" ]] || {
            echo "Missing expected library: ${source_dir}/${library}" >&2
            exit 1
        }
    done

    sudo mkdir -p "${INSTALL_DIR}" "${BACKUP_DIR}"
    for existing in \
        libze_intel_npu.so \
        libze_intel_npu.so.1 \
        libopenvino_intel_npu_compiler.so \
        libopenvino_intel_npu_compiler_loader.so; do
        if [[ ! -e "${BACKUP_DIR}/${existing}" && ! -L "${BACKUP_DIR}/${existing}" ]] \
                && [[ -e "${INSTALL_DIR}/${existing}" || -L "${INSTALL_DIR}/${existing}" ]]; then
            sudo cp -a "${INSTALL_DIR}/${existing}" "${BACKUP_DIR}/${existing}"
        fi
    done

    sudo install -m 0755 \
        "${source_dir}/libze_intel_npu.so.${VERSION}" \
        "${INSTALL_DIR}/libze_intel_npu.so.${VERSION}"
    sudo install -m 0755 \
        "${source_dir}/libopenvino_intel_npu_compiler.so" \
        "${INSTALL_DIR}/libopenvino_intel_npu_compiler.so"
    sudo install -m 0755 \
        "${source_dir}/libopenvino_intel_npu_compiler_loader.so" \
        "${INSTALL_DIR}/libopenvino_intel_npu_compiler_loader.so"
    sudo ln -sfn "libze_intel_npu.so.${VERSION}" "${INSTALL_DIR}/libze_intel_npu.so.1"
    sudo ln -sfn "libze_intel_npu.so.1" "${INSTALL_DIR}/libze_intel_npu.so"
    sudo ldconfig

    verify
    echo "Intel NPU userspace ${VERSION} installed. Existing versioned libraries were preserved."
}

rollback() {
    if [[ ! -d "${BACKUP_DIR}" ]]; then
        echo "Backup directory not found: ${BACKUP_DIR}" >&2
        exit 1
    fi

    sudo rm -f \
        "${INSTALL_DIR}/libze_intel_npu.so.${VERSION}" \
        "${INSTALL_DIR}/libopenvino_intel_npu_compiler.so" \
        "${INSTALL_DIR}/libopenvino_intel_npu_compiler_loader.so"

    for saved in "${BACKUP_DIR}"/*; do
        [[ -e "${saved}" || -L "${saved}" ]] || continue
        sudo cp -a "${saved}" "${INSTALL_DIR}/$(basename "${saved}")"
    done
    sudo ldconfig
    echo "Intel NPU userspace symlinks restored from ${BACKUP_DIR}."
}

case "${1:-install}" in
    install) install_driver ;;
    rollback) rollback ;;
    verify) verify ;;
    -h|--help|help) usage ;;
    *) usage >&2; exit 2 ;;
esac
