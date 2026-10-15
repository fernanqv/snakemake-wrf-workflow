set +u
TOOLCHAIN_SUFFIX="-foss-2024a-dmpar"
EESSI_INIT="/cvmfs/software.eessi.io/versions/2025.06/init/bash"
WRF_VERSION="4.6.1"
WPS_VERSION="4.6.0"
LOCAL_MODULES_PATH="/gpfs/users/fernandezv/repos/snakemake-wrf-workflow/.easybuild/modules/all"
source $EESSI_INIT
module load EESSI-extend
module use $LOCAL_MODULES_PATH
module load WRF/${WRF_VERSION}${TOOLCHAIN_SUFFIX}
module load WPS/${WPS_VERSION}${TOOLCHAIN_SUFFIX} 
export OMPI_MCA_btl=tcp,self,vader
export OMPI_MCA_pml=ob1;
set -u