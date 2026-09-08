#!/bin/bash
# Script to compile WRF and WPS using Spack
# Usage: bash spack/build-wrf-spack.sh

set -e

BASEPATH=$(pwd)
SPACK_ENV="${BASEPATH}/spack"
COMPILATION_DIR="${BASEPATH}/compilation"
WRF_VERSION="${WRF_VERSION:-4.6.1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create compilation directory
mkdir -p "${COMPILATION_DIR}"
cd "${COMPILATION_DIR}"

log_info "Starting WRF/WPS compilation with Spack"
log_info "WRF Version: ${WRF_VERSION}"
log_info "WPS Version: ${WPS_VERSION}"

# Activate spack environment
if command -v spack &> /dev/null; then
    log_info "Spack found at: $(which spack)"
else
    log_error "Spack not found. Please load spack module or source spack installation."
    exit 1
fi

# Create and activate environment
log_info "Setting up Spack environment..."
if [ -d "${SPACK_ENV}/env" ]; then
    spack env activate "${SPACK_ENV}/env"
else
    spack env create -d "${SPACK_ENV}/env" "${SPACK_ENV}/environments.yaml"
    spack env activate "${SPACK_ENV}/env"
fi

# Install dependencies
log_info "Installing dependencies..."
spack install

# Install WRF
log_info "Installing WRF ${WRF_VERSION}..."
spack install wrf@${WRF_VERSION} %gcc@11.3.0 ^netcdf-fortran ^jasper

# Install WPS
log_info "Installing WPS ${WPS_VERSION}..."
spack install wps@${WPS_VERSION} %gcc@11.3.0 ^netcdf-fortran

# Get installation paths
WRF_INSTALL_DIR=$(spack location -i wrf@${WRF_VERSION})
WPS_INSTALL_DIR=$(spack location -i wps@${WPS_VERSION})

log_info "WRF installed at: ${WRF_INSTALL_DIR}"
log_info "WPS installed at: ${WPS_INSTALL_DIR}"

# Create symlinks
log_info "Creating symlinks..."
ln -sf "${WRF_INSTALL_DIR}" "${COMPILATION_DIR}/WRF"
ln -sf "${WPS_INSTALL_DIR}" "${COMPILATION_DIR}/WPS"

# Create module script for runtime
cat > "${COMPILATION_DIR}/wrf_env.sh" << 'EOF'
#!/bin/bash
# Load WRF/WPS environment from Spack

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPACK_ENV_PATH="$(dirname "${SCRIPT_DIR}")/spack/env"

# Activate spack environment
source $(spack location -i spack)/share/spack/setup-env.sh
spack env activate "${SPACK_ENV_PATH}"

# Export WRF/WPS paths
export WRF_DIR="${SCRIPT_DIR}/WRF"
export WPS_DIR="${SCRIPT_DIR}/WPS"
export PATH="${WRF_DIR}/main:${WPS_DIR}/main:${PATH}"

echo "WRF environment loaded"
echo "WRF_DIR: ${WRF_DIR}"
echo "WPS_DIR: ${WPS_DIR}"
EOF

chmod +x "${COMPILATION_DIR}/wrf_env.sh"

log_info "Compilation completed successfully!"
log_info "To use WRF/WPS, source: ${COMPILATION_DIR}/wrf_env.sh"
