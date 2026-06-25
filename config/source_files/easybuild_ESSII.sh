
set +u
source /cvmfs/software.eessi.io/versions/2025.06/init/bash
module load WRF/4.6.1-foss-2024a-dmpar
set -u
export OMPI_MCA_pml=ob1
export OMPI_MCA_btl=self,tcp        