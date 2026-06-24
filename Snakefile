from itertools import product
from pathlib import Path

configfile: "config/config.yaml"

RUN_BASE_DIR_TEMPLATE = config["run_dir"]
GRIB_BASE_DIR = config["grib_basedir"]
WPS_INSTALL_DIR = config["wps_install_dir"]
ERA5_DOMAIN = config["era5_domain"]
MONTHS = [f"{month:02d}" for month in range(11, 12)]
ERA5_FILETYPES = ["pl", "sl"]
GEO_EM_PATH = config["geo_em_path"].format(era5_domain=ERA5_DOMAIN)
print(f"RUN_BASE_DIR_TEMPLATE: {RUN_BASE_DIR_TEMPLATE}")
print(f"GEO_EM_PATH: {GEO_EM_PATH}")

def get_run_dir(year):
    """Expand run_dir template with domain and year"""
    return RUN_BASE_DIR_TEMPLATE.format(year=year)

RUNS = config["runs"]
ALL_METGRIDS = [
    #str(Path(get_run_dir(run)) / "metgrid.done")
    str(Path(get_run_dir(year)) / "metgrid.done")
    for year in RUNS
]

localrules: all, namelist_wps, namelist_wps_geogrid

rule all:
    input:
        ALL_METGRIDS


# TO DO: Download geog_data_path from https://www2.mmm.ucar.edu/wrf/site/access_code/geog_data.html if not available

rule namelist_wps:
    output: 
        f"{RUN_BASE_DIR_TEMPLATE}/namelist.wps"
    params:
        geog_data_path=str(Path(config["geog_data_path"])),
        geo_em_path=GEO_EM_PATH,
        namelist_wps=config["namelist_wps"],
        GEOGRID_TBL=config["GEOGRID.TBL"],
        wps_dir=WPS_INSTALL_DIR,
    shell:
        """
        mkdir -p {params.run_dir}
        cd {params.run_dir}
        jinja2 {params.namelist_wps_template} \
            -D start_year={wildcards.year} \
            -D end_year={wildcards.year} \
            -D geog_data_path={params.geog_data_path} \
            -o namelist.wps
        touch {output}
        """

rule namelist_wps_geogrid:
    output: 
        f"{GEO_EM_PATH}/namelist.wps"
    params:
        geog_data_path=str(Path(config["geog_data_path"])),
        geo_em_path=GEO_EM_PATH,
        namelist_wps=config["namelist_wps"],
    shell:
        """
        mkdir -p {params.geo_em_path}
        cd {params.geo_em_path}
        jinja2 {params.namelist_wps} \
            -D geog_data_path={params.geog_data_path} \
            -o namelist.wps
        touch {output}
        """

rule geogrid:
    input:
        namelist_wps=str(Path(GEO_EM_PATH) / "namelist.wps"),
    output:
        str(Path(GEO_EM_PATH) / "geogrid.done")
    params:
        geog_data_path=str(Path(config["geog_data_path"])),
        geo_em_path=GEO_EM_PATH,
        namelist_wps=config["namelist_wps"],
        GEOGRID_TBL=config["GEOGRID.TBL"],
        wps_dir=WPS_INSTALL_DIR,
    resources:
        tasks= 2,
        mpi= "mpirun",
    shell:
        """
        cd {params.geo_em_path}
        mkdir -p geogrid
        ln -sf {params.wps_dir}/geogrid/{params.GEOGRID_TBL} {params.geo_em_path}/geogrid/GEOGRID.TBL
        {resources.mpi} -n {resources.tasks} geogrid.exe
        touch {output}
        """

rule download_ERA5:
    output:
        f"{GRIB_BASE_DIR}/{{domain}}/{{year}}/ERA5-{{year}}{{month}}-{{filetype}}.grib"
    params:
        data_dir=GRIB_BASE_DIR,
    shell:
        """
        echo "Running: python ERA5/retrieve_era5.py {wildcards.year} {wildcards.month} {wildcards.filetype} {params.data_dir} {wildcards.domain}"
        python ERA5/retrieve_era5.py {wildcards.year} {wildcards.month} {wildcards.filetype} {params.data_dir} {wildcards.domain}
        """

rule ungrib:
    input:
        gribs=lambda wildcards: expand(
            f"{GRIB_BASE_DIR}/{ERA5_DOMAIN}/{{year}}/ERA5-{{year}}{{month}}-{{filetype}}.grib",
            year=wildcards.year,
            month=MONTHS,
            filetype=ERA5_FILETYPES,
        ),
        namelist_wps=lambda wildcards: str(Path(get_run_dir(wildcards.year)) / "namelist.wps"),
    output:
        f"{RUN_BASE_DIR_TEMPLATE}/ungrib.done"
    params:
        grib_dir=lambda wildcards: str(Path(GRIB_BASE_DIR) / ERA5_DOMAIN / wildcards.year),
        run_dir=lambda wildcards: get_run_dir(wildcards.year),
        wps_dir=WPS_INSTALL_DIR,
        VTable=config["Vtable"],
    shell:
        """ 
        
        mkdir -p {params.run_dir}
        cd {params.run_dir}

        export PATH=$PATH:{params.wps_dir}
        
        # Link GRIB files
        link_grib.csh {params.grib_dir}/*.grib

        # Link Vtable
        ln -sf {params.wps_dir}/ungrib/Variable_Tables/{params.VTable} Vtable

        ungrib.exe

        touch {output}
        """

rule metgrid:
    input:
        ungrib=lambda wildcards: str(Path(get_run_dir(wildcards.year)) / "ungrib.done"),
        geogrid=str(Path(GEO_EM_PATH) / "geogrid.done"),
    output:
        f"{RUN_BASE_DIR_TEMPLATE}/metgrid.done"
    params:
        run_dir=lambda wildcards: get_run_dir(wildcards.year),
        wps_dir=WPS_INSTALL_DIR,
        geo_em_path=GEO_EM_PATH,
        METGRID_TBL=config["METGRID.TBL"],
    resources:
        tasks= 2,
        mpi= "mpirun",
    shell:
        """
        # set +u
        # source /cvmfs/software.eessi.io/versions/2025.06/init/bash
        # #module purge

        # module use /gpfs/users/fernandezv/repos/snakemake-wrf-workflow/eb/easybuild/modules/all
        # module load WPS/4.6.0-foss-2024a-dmpar
        # set -u
        # export OMPI_MCA_pml=ob1
        # export OMPI_MCA_btl=self,tcp

        #source /gpfs/users/fernandezv/repos/snakemake-wrf-workflow/config/source_files/wps_josipa.sh

        echo "Running metgrid for year {wildcards.year} in {params.run_dir}"
        
        cd {params.run_dir}
        mkdir -p metgrid
        ln -sf {params.geo_em_path}/geo_em* .
        ln -sf {params.wps_dir}/metgrid/{params.METGRID_TBL} {params.run_dir}/metgrid/GEOGRID.TBL
        {resources.mpi} -n {resources.tasks} metgrid.exe

        touch {output}
        """
