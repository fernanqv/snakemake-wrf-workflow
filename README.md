# Snakemake WRF Workflow

This repository contains a Snakemake workflow to run a WPS/WRF simulation.

The main workflow is defined in `Snakefile`. It reads `config/config.yaml`, where
the run years, ERA5 domain, input/output directories, WPS/WRF installation paths,
template namelists, and table names are configured. The Snakefile uses those
values to build the WPS and WRF steps: namelist generation, geogrid, ERA5
download, ungrib, metgrid, real, and wrf.

## Configuration

Edit `config/config.yaml` before running the workflow. The most important values
are:

- `runs`: years to simulate.
- `grib_basedir`: directory where ERA5 GRIB files are stored.
- `run_dir`: per-year WRF run directory template.
- `wps_install_dir` and `wrf_install_dir`: WPS and WRF installation directories.
- `geog_data_path`: WPS geographical data directory.
- `era5_domain`: ERA5 domain name.
- `geo_em_path`: directory for geogrid outputs.
- `namelist_wps` and `namelist_input`: Jinja2 namelist templates.

### **Optional**: WPS/WRF Compilation

The workflow can optionally orchestrate the download, audit, and compilation of the required WPS and WRF binaries via an integrated external Snakemake module utilizing EESSI software stacks.

To enable automated compilation before running the simulation:

1. In `config/config.yaml`, set `compile_software: true`.
2. Configure the GitHub repository target, version tag, and EESSI compiler toolchain environment variables:

```yaml
enable_compilation: true
compilation_repo: "orviz/snakemake-wrf-wps-compilation"
compilation_version: "0.4.0"

compilation_config:
  eessi_init_script: "/cvmfs/software.eessi.io/versions/2025.06/init/bash"
  wps_version: "4.6.0"
  wrf_version: "4.6.1"
  compiler: "intel"
  toolchain_suffix: "-foss-2024a-dmpar"
```

When active, the workflow automatically injects your local `wps_install_dir` and `wrf_install_dir` paths into the compilation module. The binaries (`ungrib.exe` and `wrf.exe`) will be built on-the-fly and deposited directly into those target installation folders as dynamic prerequisites before any WPS or WRF simulation rules are triggered.

*Note: If `enable_compilation` is set to `false`, the workflow bypasses the external compilation module entirely and expects pre-existing binaries to be available at the configured installation paths.*

## Examples

There are two example configurations in the repository. The current `Snakefile`
is intended to be used with the `toy_example` templates in
`config/templates/toy_example/`. This example runs a light WRF simulation over
only a few days.

The ERA5 helper `ERA5/retrieve_era5_days4_6.py` was created for the toy example
to reduce the workflow runtime by downloading only the required days.

## Workflow Execution

This project uses Pixi to manage its environment and execute workflows via automated tasks.

### 1. Running Locally

To validate the workflow structure or run small test domains on your local machine:

```bash
# Dry run to preview the execution plan
pixi run dry-run

# Execute locally using all available cores
pixi run run-local
```

*Note: If you need to append extra Snakemake arguments, like targeting a specific rule or requesting a fixed number of cores, you can pass them directly at the end of the command, for example: `pixi run run-local --cores 4`*

### 2. Running on HPC

HPC cluster configurations and Slurm scheduler flags are decoupled from the scientific code using *Git Worktrees* to ensure project portability.

- **Step 2.1: Embed the HPC profile**

Initialize the cluster infrastructure `hpc-profiles` branch into your local profiles directory. For instance, adding Altamira cluster profile configuration will be done through:

```bash
git worktree add config/profiles hpc-profiles
```

The command above will populate `config/profiles/` with the available cluster configurations (e.g., `altamira/`), each containing its own Slurm presets and a `set_env.sh` file.

- **Step 2.2: Launch the Simulation**

To execute the workflow, use the unifed Pixi's `hpc-profile` task. **Pass the name of the HPC profile as the first argument**, followed by any optional Snakemake flags:

```bash
# Standard execution on Altamira
pixi run hpc-profile altamira

# Dry-run execution on Altamira
pixi run hpc-profile altamira --dry-run

# Execution limiting concurrent Slurm jobs
pixi run hpc-profile altamira --jobs 15
```

*Note: As described in the local execution section, any extra Snakemake argument is passed directly to the pixi task. However, Slurm-related settings are defined through the profile configuration under `profiles/<profile>/config.yaml`*

*Note: For cluster-specific validations (like checking NetCDF paths via ldd on Altamira), please refer to the internal documentation at `config/profiles/<profile>/README.md` after mounting the worktree.*

### 3. Working with HPC profiles (Git Worktree)

Once the Git Worktree is set up, any update in the configuration of any HPC profile will work as follows:

- **Download configuration updates**:

```bash
cd config/profiles/altamira
git pull origin hpc-profiles
```

- **Upload configuration changes**:

```bash
cd config/profiles/altamira
# E.g. modify config.yaml...
git add config.yaml
git commit -m "Increase memory limits for WRF simulation"
git push origin hpc-profiles
```

## DAG

The workflow DAG is shown below. The repository also includes the PDF version in
`dag.pdf`.

![Workflow DAG](dag.png)

Regenerate it with:

```bash
snakemake --dag | dot -Tpdf > dag.pdf
snakemake --dag | dot -Tpng > dag.png
```

## TODO

- Decide how to protect the workflow from missing control files due to storage
  problems such as partition unmounts.
- Create a Snakefile to run CORDEX in Altamira. The main difference is that the
  domain is provided as an argument.
- Decide which symbolic links are created by default and which are provided by
  the user. For example, `GEOGRID.TBL` and `METGRID.TBL` are provided by the
  user, but `Vtable` is created by default. The user can provide a custom
  `Vtable` if desired.
- Download `geog_data_path` from
  https://www2.mmm.ucar.edu/wrf/site/access_code/geog_data.html if it is not
  available.
- Improve `ERA5/retrieve_era5.py` to support days as an argument. Decide how to
  handle this in the Snakefile.
- Ask Josipa if it would be possible to clean the WRF/run template folder.
  Decide how to deal with the excludes:
  `/gpfs/projects/meteo/WORK/ASNA/projects/cordex-core/02_SAM12_evaluation/rundir/WRFv4.6.1-cordex_core/run/`.
