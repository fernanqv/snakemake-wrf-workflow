# configuration vars

# paths
basepath=$(pwd)
geo_em=$basepath/data/geo_em
era5=/gpfs/res_projects/uc15/uc15003/ERA5

# Simulation settings
domain="EUR"
year=2000

WPS=$basepath/compilation/WPS

# Workflow execution

# Add executables to path
export PATH=$PATH:$WPS

# Prepare input files

# link Vtable
mkdir ungrib metgrid
ln -sf $WPS/ungrib/Variable_Tables/Vtable.ERA-interim.pl Vtable
ln -sf $WPS/metgrid/METGRID.TBL .


./link_grib.csh $era5/EUR/2000/

$WPS/ungrib/ungrib.exe

source $basepath/compilation/wrf_essi.sh

$WPS/metgrid/metgrid.exe

