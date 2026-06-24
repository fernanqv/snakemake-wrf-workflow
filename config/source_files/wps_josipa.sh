ulimit -s unlimited
ulimit -l unlimited

module purge
module use /gpfs/projects/meteo/WORK/ASNA/apps/privatemodules
module load wrflibs_spack/compiler/intel-classic-2021.10.0
module load wrflibs_spack/mpi/intel-oneapi-mpi-2021.11.0
module load wrflibs_spack/netcdf-c/4.9.2-intel-oneapi-mpi-2021.11.0-intel-2021.10.0
module load wrflibs_spack/netcdf-fortran/4.6.1-intel-oneapi-mpi-2021.11.0-intel-2021.10.0
module load wrflibs_spack/jasper/2.0.32-intel-2021.10.0
module load wrflibs_spack/libpng/1.6.39-intel-2021.10.0
module load wrflibs_spack/libjpeg-turbo/3.0.0-intel-2021.10.0
#module load OPENUCX/1.15.0_intel

export NETCDF=/gpfs/projects/meteo/WORK/josipa/CMIP6toWRF/WRF_binaries/WRF_spacklibs/NETCDF/
export CC=icc
export FC=ifort
export F90=ifort
export CXX=icpc
export F77=ifort
export NETCDF4=1
export WRFIO_NCD_LARGE_FILE_SUPPORT=1

# Enable NUMA-aware process and memory allocation
export I_MPI_PIN_DOMAIN=numa
export I_MPI_PIN_PROCESSOR_LIST=all
export I_MPI_DEBUG=5
export I_MPI_HYDRA_DEBUG=1

# Improve memory locality
export KMP_SETTINGS=1
export KMP_AFFINITY=granularity=fine,compact,1,0
export KMP_STACKSIZE=512m
#export I_MPI_SHM_HEAP_VSIZE=256

# Slurm + MPI Integration - Explicitly set PMI environment
export I_MPI_FABRICS=shm:ofa
export I_MPI_PMI_LIBRARY=/usr/lib64/libpmi.so
export I_MPI_PMI2_SUPPORT=1

export PATH=$PATH:/gpfs/projects/meteo/WORK/ASNA/projects/cordex-core/02_SAM12_evaluation/rundir/WPS/