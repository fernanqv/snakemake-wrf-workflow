# Instructions to run this workflow in altamira:

# pixie shell
# source /gpfs/users/fernandezv/repos/snakemake-wrf-workflow/config/source_files/wps_josipa.sh
# snakemake --profile=config/profiles/template_slurm/ 

from itertools import product
from pathlib import Path
from shlex import quote

configfile: "config/config.yaml"

RUN_BASE_DIR_TEMPLATE = config["run_dir"]
GRIB_BASE_DIR = config["grib_basedir"]
WPS_INSTALL_DIR = config["wps_install_dir"]
WRF_INSTALL_DIR = config["wrf_install_dir"]
ERA5_DOMAIN = config["era5_domain"]
MONTHS = [f"{month:02d}" for month in range(11, 12)]
ERA5_FILETYPES = ["pl", "sl"]
GEO_EM_PATH = config["geo_em_path"].format(era5_domain=ERA5_DOMAIN)
WRF_RUN_EXCLUDE_PATTERNS = ["wrf*", "*.exe", "README*", "*rsl*", "namelist.*"]
WRF_RUN_FIND_EXCLUDES = " ".join(
    f"! -name {quote(pattern)}" for pattern in WRF_RUN_EXCLUDE_PATTERNS
)


def get_run_dir(year):
    """Expand run_dir template with domain and year"""
    return RUN_BASE_DIR_TEMPLATE.format(year=year)

RUNS = config["runs"]
ALL_WRFS = [
    str(Path(get_run_dir(year)) / "wrf.done")
    for year in RUNS
]

localrules: all, namelist_wps, namelist_wps_geogrid, namelist_input

rule all:
    input:
        ALL_WRFS

rule namelist_wps:
    output: 
        f"{RUN_BASE_DIR_TEMPLATE}/namelist.wps"
    params:
        geog_data_path=str(Path(config["geog_data_path"])),
        geo_em_path=GEO_EM_PATH,
        namelist_wps=config["namelist_wps"],
        GEOGRID_TBL=config["GEOGRID.TBL"],
        wps_dir=WPS_INSTALL_DIR,
        run_dir=lambda wildcards: get_run_dir(wildcards.year),
    shell:
        """
        mkdir -p {params.run_dir}
        cd {params.run_dir}
        jinja2 {params.namelist_wps} \
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

rule namelist_input:
    output:
        f"{RUN_BASE_DIR_TEMPLATE}/namelist.input"
    params:
        run_dir=lambda wildcards: get_run_dir(wildcards.year),
        namelist_input_template=str(Path(config["namelist_input"])),
    shell:
        """
        mkdir -p {params.run_dir}
        cd {params.run_dir}
        jinja2 {params.namelist_input_template} \
            -D start_year={wildcards.year} \
            -D end_year={wildcards.year} \
            -o namelist.input
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
        python ERA5/retrieve_era5_days4_6.py {wildcards.year} {wildcards.month} {wildcards.filetype} {params.data_dir} {wildcards.domain}
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
        echo "Running metgrid for year {wildcards.year} in {params.run_dir}"
        
        cd {params.run_dir}
        mkdir -p metgrid
        ln -sf {params.geo_em_path}/geo_em* .
        ln -sf {params.wps_dir}/metgrid/{params.METGRID_TBL} {params.run_dir}/metgrid/METGRID.TBL
        {resources.mpi} -n {resources.tasks} metgrid.exe

        touch {output}
        """

rule real:
    input:
        metgrid=lambda wildcards: str(Path(get_run_dir(wildcards.year)) / "metgrid.done"),
        namelist_input=lambda wildcards: str(Path(get_run_dir(wildcards.year)) / "namelist.input"),
    output:
        f"{RUN_BASE_DIR_TEMPLATE}/real.done"
    params:
        year=lambda wildcards: wildcards.year,
        run_dir=lambda wildcards: get_run_dir(wildcards.year),
    resources:
        tasks= 2,
        mpi= "mpirun",
    shell:
        """
        echo "Running real for year {params.year} in {params.run_dir}"
        cd {params.run_dir}
        {resources.mpi} -n {resources.tasks} real.exe
        touch {output}
        """

rule wrf:
    input:
        real=lambda wildcards: str(Path(get_run_dir(wildcards.year)) / "real.done"),
    output:
        f"{RUN_BASE_DIR_TEMPLATE}/wrf.done"
    params:
        run_dir=lambda wildcards: get_run_dir(wildcards.year),
        wrf_run_dir=str(Path(WRF_INSTALL_DIR) / "run"),
        wrf_run_find_excludes=WRF_RUN_FIND_EXCLUDES,
    resources:
        tasks=16,
        mpi="mpirun",
    shell:
        """
        echo "Running wrf for year {wildcards.year} in {params.run_dir}"
        mkdir -p {params.run_dir}
        cd {params.run_dir}
        find {params.wrf_run_dir} -maxdepth 1 -mindepth 1 \
            {params.wrf_run_find_excludes} \
            -exec ln -sf {{}} . \\;
        echo "{resources.mpi} -n {resources.tasks} wrf.exe"
        {resources.mpi} -n {resources.tasks} wrf.exe
        touch {output}
        """
