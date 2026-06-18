# Snakefile para descargar y procesar datos ERA5
# Uso:
#   snakemake --config years="[2000,2001]" domains="[EUR,IBERIA]"
#   snakemake --config runs="[{year: 2000, domain: EUR}, {year: 2001, domain: IBERIA}]"

from itertools import product
from pathlib import Path

# Configuracion
configfile: "config/config.yaml"


def as_list(value):
    if isinstance(value, (list, tuple)):
        return list(value)
    return [value]


def make_run(year, domain):
    year = str(year)
    return {
        "year": year,
        "domain": str(domain),
    }


def build_runs():
    if "runs" in config:
        return [
            make_run(run["year"], run["domain"])
            for run in config["runs"]
        ]

    years = [str(year) for year in as_list(config.get("years", config.get("year", 2000)))]
    domains = [str(domain) for domain in as_list(config.get("domains", config.get("domain", "EUR")))]
    return [
        make_run(year, domain)
        for year, domain in product(years, domains)
    ]


# Variables
GRIB_BASE_DIR = config["grib_basedir"]
RUN_BASE_DIR = config["run_basedir"]
WPS_INSTALL_DIR = config["wps_install_dir"]

MONTHS = [f"{m:02d}" for m in range(11, 12)]
RUNS = build_runs()
ALL_METGRIDS = [
    str(Path(RUN_BASE_DIR) / run["domain"] / run["year"] / ("metgrid.done"))
    for run in RUNS
]
NAMELIST_WPS_TEMPLATE = config["namelist_wps"]


localrules: all, namelist_wps
rule all:
    input:
        ALL_METGRIDS

# snakemake -n '/gpfs/users/fernandezv/repos/WRFsnamekmake/data/ERA5/EUR/2000/ERA5-200011-pl.grib'
rule download_ERA5:
    output:
        f"{GRIB_BASE_DIR}/{{domain}}/{{year}}/ERA5-{{year}}{{month}}-{{filetype}}.grib"
    params:
        year=lambda wildcards: wildcards.year,
        month=lambda wildcards: wildcards.month,
        filetype=lambda wildcards: wildcards.filetype,
        data_dir=GRIB_BASE_DIR,
        domain=lambda wildcards: wildcards.domain,
    resources:
        slurm_partition="wncompute_ifca",
        runtime=10,
        slurm_extra="--exclude=wncompute022"
    shell:
        """
        echo "Running: python ERA5/retrieve_era5.py {params.year} {params.month} {params.filetype} {params.data_dir} {params.domain}"
        python ERA5/retrieve_era5.py {params.year} {params.month} {params.filetype} {params.data_dir} {params.domain}
        """

rule namelist_wps:
    output: 
        f"{RUN_BASE_DIR}/{{domain}}/{{year}}/namelist.wps"
    params:
        year=lambda wildcards: wildcards.year,
        run_dir=lambda wildcards: str(Path(RUN_BASE_DIR) / wildcards.domain / wildcards.year),
        geo_data_path=lambda wildcards: str(Path(config["geo_em_dir"]) / wildcards.domain),
        namelist_wps_template=NAMELIST_WPS_TEMPLATE,
    shell:
        """
        mkdir -p {params.run_dir}
        cd {params.run_dir}
        jinja2 {params.namelist_wps_template} -D start_year={params.year} -D end_year={params.year} -D geo_data_path={params.geo_data_path} -o namelist.wps
        touch {output}
        """

rule ungrib:
    input:
        gribs=lambda wildcards: expand(
            f"{GRIB_BASE_DIR}/{{domain}}/{{year}}/ERA5-{{year}}{{month}}-{{filetype}}.grib",
            domain=wildcards.domain,
            year=wildcards.year,
            month=MONTHS,
            filetype=["pl", "sl"],
        ),
        namelist_wps=f"{RUN_BASE_DIR}/{{domain}}/{{year}}/namelist.wps"

    output:
        f"{RUN_BASE_DIR}/{{domain}}/{{year}}/ungrib.done"
    params:
        year=lambda wildcards: wildcards.year,
        grib_dir=lambda wildcards: str(Path(GRIB_BASE_DIR) / wildcards.domain / wildcards.year),
        run_dir=lambda wildcards: str(Path(RUN_BASE_DIR) / wildcards.domain / wildcards.year),
        geo_data_path=lambda wildcards: str(Path(config["geo_em_dir"]) / wildcards.domain),
        wps_dir=WPS_INSTALL_DIR,
        VTable=config["Vtable"],
    resources:
        slurm_partition="wncompute_ifca",
        runtime=10,
        slurm_extra="--exclude=wncompute022"
    shell:
        """ 
        mkdir -p {params.run_dir}
        cd {params.run_dir}

        export PATH=$PATH:{params.wps_dir}
        
        # Link GRIB files
        link_grib.csh {params.grib_dir}/

        # Link geo_em files
        ln -sf {params.geo_data_path}/* .

        # Link Vtable
        ln -sf {params.wps_dir}/ungrib/Variable_Tables/{params.VTable} Vtable
        echo "antes"
        ungrib.exe
        echo "despues"

        touch {output}
        """

rule metgrid:
    input:
        lambda wildcards: expand(
            f"{RUN_BASE_DIR}/{{domain}}/{{year}}/ungrib.done",
            domain=wildcards.domain,
            year=wildcards.year,
        )
    output:
        f"{RUN_BASE_DIR}/{{domain}}/{{year}}/metgrid.done"
    params:
        year=lambda wildcards: wildcards.year,
        run_dir=lambda wildcards: str(Path(RUN_BASE_DIR) / wildcards.domain / wildcards.year),
        wps_dir=WPS_INSTALL_DIR,
        METGRID_TBL=config["METGRID.TBL"],
    # resources:
    #     slurm_partition="wncompute_meteo",
    #     runtime=10,
    #     slurm_extra="--exclude=wncompute022"
    shell:
        """
        set +u
        source /cvmfs/software.eessi.io/versions/2025.06/init/bash
        #module purge

        module use /gpfs/users/fernandezv/repos/snakemake-wrf-workflow/eb/easybuild/modules/all
        module load WPS/4.6.0-foss-2024a-dmpar
        set -u
        echo "Running metgrid for year {params.year} in {params.run_dir}"

        cd {params.run_dir}
        mkdir -p metgrid
        cd metgrid
        ln -sf {params.wps_dir}/metgrid/{params.METGRID_TBL} .
        cd -

        export OMPI_MCA_pml=ob1
        export OMPI_MCA_btl=self,tcp
        metgrid.exe

        touch {output}
        """

rule real:
    input:
        lambda wildcards: expand(
            f"{RUN_BASE_DIR}/{{domain}}/{{year}}/real.done",
            domain=wildcards.domain,
            year=wildcards.year,
        )
    output:
        f"{RUN_BASE_DIR}/{{domain}}/{{year}}/metgrid.done"
    params:
        year=lambda wildcards: wildcards.year,
        run_dir=lambda wildcards: str(Path(RUN_BASE_DIR) / wildcards.domain / wildcards.year),
    resources:
        slurm_partition="wncompute_meteo",
        runtime=10,
        slurm_extra="--exclude=wncompute022"
    shell:
        """
        set +u
        source /cvmfs/software.eessi.io/versions/2025.06/init/bash
        module load WRF/4.6.1-foss-2024a-dmpar
        set -u

        echo "Running real for year {params.year} in {params.run_dir}"
        cd {params.run_dir}
        export OMPI_MCA_pml=ob1
        export OMPI_MCA_btl=self,tcp
        real.exe
        touch {output}
        """

    
