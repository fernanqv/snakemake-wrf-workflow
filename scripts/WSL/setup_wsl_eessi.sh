#!/usr/bin/env bash
set -Eeuo pipefail

# Author: Valvanuz Fernández <valvanuz.fernandez@unican.es>
#
# Provision an Ubuntu 24.04 WSL2 distribution for EESSI/WRF.
#
# Run from inside the distribution:
#   sudo ./scripts/setup_wsl_eessi.sh
#
# Override the default Linux user if required:
#   TARGET_USER=myuser sudo -E ./scripts/setup_wsl_eessi.sh

TARGET_USER="${TARGET_USER:-${SUDO_USER:-wrf}}"
EESSI_VERSION="${EESSI_VERSION:-2025.06}"
WRF_MODULE="${WRF_MODULE:-WRF/4.6.1-foss-2024a-dmpar}"
CVMFS_QUOTA_MB="${CVMFS_QUOTA_MB:-10000}"

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: run this script with sudo or as root." >&2
    exit 1
fi

if ! grep -qi microsoft /proc/sys/kernel/osrelease; then
    echo "ERROR: this script is intended for Ubuntu running under WSL2." >&2
    exit 1
fi

if ! id "${TARGET_USER}" >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash --groups sudo "${TARGET_USER}"
fi

cat >/etc/sudoers.d/90-wrf-setup <<EOF
${TARGET_USER} ALL=(ALL) NOPASSWD:ALL
EOF
chmod 0440 /etc/sudoers.d/90-wrf-setup
visudo -cf /etc/sudoers.d/90-wrf-setup

# WSL runs this command as root whenever the distribution starts. CernVM-FS
# deliberately uses wsl2_start instead of autofs inside WSL2.
cat >/etc/wsl.conf <<EOF
[boot]
systemd=true
command=/usr/bin/cvmfs_config wsl2_start

[user]
default=${TARGET_USER}
EOF

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y
apt-get install -y \
    autofs \
    build-essential \
    ca-certificates \
    curl \
    file \
    fuse3 \
    git \
    lsb-release \
    rsync \
    tcsh \
    unzip \
    wget

SETUP_TMP="$(mktemp -d)"
trap 'rm -rf -- "${SETUP_TMP}"' EXIT

wget -q \
    -O "${SETUP_TMP}/cvmfs-release.deb" \
    https://cvmrepo.s3.cern.ch/cvmrepo/apt/cvmfs-release-latest_all.deb
dpkg -i "${SETUP_TMP}/cvmfs-release.deb"
apt-get update
apt-get install -y cvmfs

wget -q \
    -O "${SETUP_TMP}/cvmfs-config-eessi.deb" \
    https://github.com/EESSI/filesystem-layer/releases/download/latest/cvmfs-config-eessi_latest_all.deb
dpkg -i "${SETUP_TMP}/cvmfs-config-eessi.deb"

cat >/etc/cvmfs/default.local <<EOF
CVMFS_CLIENT_PROFILE=single
CVMFS_QUOTA_LIMIT=${CVMFS_QUOTA_MB}
CVMFS_HTTP_PROXY=DIRECT
EOF

cvmfs_config setup
cvmfs_config chksetup
cvmfs_config wsl2_start
cvmfs_config probe software.eessi.io

install -d -o "${TARGET_USER}" -g "${TARGET_USER}" \
    "/home/${TARGET_USER}/src" \
    "/home/${TARGET_USER}/software" \
    "/home/${TARGET_USER}/wrf-data" \
    "/home/${TARGET_USER}/wrf-runs"

EESSI_INIT="/cvmfs/software.eessi.io/versions/${EESSI_VERSION}/init/bash"
if [[ ! -r "${EESSI_INIT}" ]]; then
    echo "ERROR: EESSI initialization script not found: ${EESSI_INIT}" >&2
    exit 1
fi

# EESSI initialization and environment modules must run in a Bash process.
runuser -u "${TARGET_USER}" -- bash -lc \
    "source '${EESSI_INIT}' >/dev/null && \
     module load '${WRF_MODULE}' && \
     echo 'Loaded module: ${WRF_MODULE}' && \
     command -v wrf.exe && \
     command -v real.exe && \
     command -v mpirun && \
     if ldd \"\$(command -v wrf.exe)\" | grep -q 'not found'; then \
         echo 'ERROR: wrf.exe has unresolved shared libraries.' >&2; \
         ldd \"\$(command -v wrf.exe)\" | grep 'not found' >&2; \
         exit 1; \
     fi"

echo
echo "EESSI/WRF provisioning completed successfully."
echo "Restart this distribution once from PowerShell:"
echo "  wsl.exe --terminate <DISTRO_NAME>"
echo "  wsl.exe -d <DISTRO_NAME>"
