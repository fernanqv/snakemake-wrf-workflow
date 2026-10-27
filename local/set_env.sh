#/usr/bin/env bash

set +u

# ------------------------------------------------------------- #
# Default runtime settings injected by Snakemake: DO NOT MODIFY #
# ------------------------------------------------------------- #
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)" # hack

LOCAL_MODULES_PATH="${LOCAL_MODULES_PATH:-${REPO_ROOT}/.easybuild/modules/all}"
WRF_VERSION="${WRF_VERSION:-4.6.1}"
WPS_VERSION="${WPS_VERSION:-4.6.0}"
TOOLCHAIN_SUFFIX="${TOOLCHAIN_SUFFIX:-"-foss-2024a-dmpar"}"

# -------------------------------------------------------------- #
# Custom user runtime settings & Overrides: MODIFICATION ALLOWED #
# -------------------------------------------------------------- #
EESSI_INIT="/cvmfs/software.eessi.io/versions/2025.06/init/bash"

source $EESSI_INIT
module load EESSI-extend
module use $LOCAL_MODULES_PATH
module load WRF/${WRF_VERSION}${TOOLCHAIN_SUFFIX}
module load WPS/${WPS_VERSION}${TOOLCHAIN_SUFFIX} 

set -u
