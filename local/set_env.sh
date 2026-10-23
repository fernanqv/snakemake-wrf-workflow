set +u

TOOLCHAIN_SUFFIX="-foss-2024a-dmpar"
EESSI_INIT="/cvmfs/software.eessi.io/versions/2025.06/init/bash"
WRF_VERSION="4.6.1"
WPS_VERSION="4.6.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)" # hack
LOCAL_MODULES_PATH="${REPO_ROOT}/.easybuild/modules/all"

source $EESSI_INIT
module load EESSI-extend
module use $LOCAL_MODULES_PATH
module load WRF/${WRF_VERSION}${TOOLCHAIN_SUFFIX}
module load WPS/${WPS_VERSION}${TOOLCHAIN_SUFFIX} 
set -u
