
import os
import logging
import cdsapi
import sys

def retrieve_era5(year: str, month: str, source: str, base_dir: str, domain_coords: list = None, domain_name: str = None) -> str:
    """
    Retrieve ERA5 data for a given year, month and source type.

    Args:
        year: Year as a string, e.g. "2020".
        month: Month as a zero-padded string, e.g. "01".
        source: Either "pl" (pressure levels) or "sl" (single levels).
        base_dir: Directory where the downloaded GRIB file will be saved.
        domain_coords: Optional. Geographical domain as an iterable [north, west, south, east].
        domain_name: Optional. Name of the geographical domain (one of list_domain_names).

    Note:
        The caller must provide exactly one of domain_coords or domain_name. If both or none
        are provided a ValueError is raised.

    Returns:
        The path to the downloaded GRIB file (set later in the function).
    """
    # Predefined named domains (extend as needed)
    list_domain_names = {
        "EUR": [90, -50, 0, 70],   # north, west, south, east (matches previous defaults)
        "SAM": [20, -100, -70, -20]
    }

    # Extract optional domain arguments if present in the function signature.
    # (This code assumes the function signature has optional parameters
    # `domain_coords=None` and `domain_name=None` when you update the signature.)
    domain_coords_provided = "domain_coords" in locals() and locals().get("domain_coords") is not None
    domain_name_provided = "domain_name" in locals() and locals().get("domain_name") is not None

    if domain_coords_provided and domain_name_provided:
        raise ValueError("Provide only one of domain_coords or domain_name, not both.")

    if not domain_coords_provided and not domain_name_provided:
        raise ValueError("You must provide either domain_coords or domain_name.")

    if domain_coords_provided:
        coords = list(locals().get("domain_coords"))
        if len(coords) != 4:
            raise ValueError("domain_coords must be an iterable of four values: [north, west, south, east].")
        domain_name= str(coords).replace("-","m").replace(",","_").replace(" ","").replace("[","").replace("]","")
    else:
        name = locals().get("domain_name")
        if name not in list_domain_names:
            valid = ", ".join(sorted(list_domain_names.keys()))
            raise ValueError(f"Unknown domain_name '{name}'. Valid names: {valid}")
        coords = list_domain_names[name]

    if source not in ["pl", "sl"]:
        raise ValueError("source must be 'pl' or 'sl'")

    output_dir = f"{base_dir}/{domain_name}/{year}/"

    # Ensure output directory exists (year subfolder)
    os.makedirs(output_dir, exist_ok=True)


    # Logger per job
    current_dir = os.path.basename(os.getcwd())
    log_file = f"ERA5_{current_dir}.log"
    logger1 = logging.getLogger('ERA5_logger_%s%s%s' % (year, month, source))
    logger1.setLevel(logging.INFO)
    fh1 = logging.FileHandler(log_file)
    fh1.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
    if not logger1.handlers:
        logger1.addHandler(fh1)


    logger1.info('START_DOWNLOAD')

    client = cdsapi.Client()

    cds_requests = {
        # ----------------------------------------------------
        # REQUEST 1: ERA5 PRESSURE LEVELS (Upper Atmosphere)
        # ----------------------------------------------------
        "pl": {
            "dataset": "reanalysis-era5-pressure-levels",
            "request": {
                "product_type": ["reanalysis"],
                "variable": [
                    "geopotential",
                    "relative_humidity",
                    "specific_humidity",
                    "temperature",
                    "u_component_of_wind",
                    "v_component_of_wind"
                ],
                "year": [year],
                "month": [month],
                "day": [
                    "01", "02", "03", "04", "05", "06", "07", "08", "09",
                    "10", "11", "12", "13", "14", "15", "16", "17", "18",
                    "19", "20", "21", "22", "23", "24", "25", "26", "27",
                    "28", "29", "30", "31"
                ],
                "time": ["00:00", "06:00", "12:00", "18:00"],
                "pressure_level": [
                        "1", "2", "3",
                        "5", "7", "10",
                        "20", "30", "50",
                        "70", "100", "125",
                        "150", "175", "200",
                        "225", "250", "300",
                        "350", "400", "450",
                        "500", "550", "600",
                        "650", "700", "750",
                        "775", "800", "825",
                        "850", "875", "900",
                        "925", "950", "975",
                        "1000"
                    ],
                "data_format": "grib",
                "download_format": "unarchived",
                "area": coords
            },
            "target": f"{output_dir}/ERA5-{year}{month}-pl.grib"
        },

        # ----------------------------------------------------
        # REQUEST 2: ERA5 SINGLE LEVELS (Surface/Ground)
        # ----------------------------------------------------
        "sl": {
            "dataset": "reanalysis-era5-single-levels",
            "request": {
                "product_type": ["reanalysis"],
                "variable": [
                    "10m_u_component_of_wind",
                    "10m_v_component_of_wind",
                    "2m_dewpoint_temperature",
                    "2m_temperature",
                    "mean_sea_level_pressure",
                    "sea_surface_temperature",
                    "surface_pressure",
                    "skin_temperature",
                    "snow_depth",
                    "soil_temperature_level_1",
                    "soil_temperature_level_2",
                    "soil_temperature_level_3",
                    "soil_temperature_level_4",
                    "volumetric_soil_water_layer_1",
                    "volumetric_soil_water_layer_2",
                    "volumetric_soil_water_layer_3",
                    "volumetric_soil_water_layer_4",
                    "land_sea_mask",
                    "sea_ice_cover"
                ],
                "year": [year],
                "month": [month],
                "day": [
                    "01", "02", "03", "04", "05", "06", "07", "08", "09",
                    "10", "11", "12", "13", "14", "15", "16", "17", "18",
                    "19", "20", "21", "22", "23", "24", "25", "26", "27",
                    "28", "29", "30", "31"
                ],
                "time": ["00:00", "06:00", "12:00", "18:00"],
                "data_format": "grib",
                "download_format": "unarchived",
                "area": coords
            },
            "target": f"{output_dir}/ERA5-{year}{month}-sl.grib"
        }
    }

    try:
        client.retrieve(
            cds_requests[source]['dataset'],
            cds_requests[source]['request'],
            cds_requests[source]['target']
        )
        logger1.info('END_DOWNLOAD')
    except Exception as e:
        print("Error", e)
        logger1.info(f"FAILED_DOWNLOAD: {e}")
        sys.exit(1)

    return cds_requests[source]['target']

if __name__ == "__main__":
    # Example usage
    # Take arguments from command line
    year = sys.argv[1]  # e.g. "2020"
    month = sys.argv[2]  # e.g. "01"
    source = sys.argv[3]  # "pl" or "sl"
    base_dir = sys.argv[4]  # e.g. "/path/to/data/"
    domain = sys.argv[5] # e.g. "europe" or "-10_20_-50_60"

    # Examples of how to run from command line:
    # python retrieve_era5.py 2021 01 pl data_folder EUR    
    # python retrieve_era5.py 2021 01 pl data_folder 90_-50_0_70
    # python retrieve_era5.py 2021 01 pl /home/valvanuz/wrf/data/ EUR  
    # python retrieve_era5.py 2021 01 pl /home/valvanuz/wrf/data/ 90_-50_0_70
    
    # output files: data/europe/2021 or data/90m50_0_70/2021 

    if domain.startswith("-") or domain[0].isdigit():
        coords = [int(x) for x in domain.split("_")]
        domain_name= str(coords).replace("-","m").replace(",","_").replace(" ","").replace("[","").replace("]","")
        retrieve_era5(year, month, source, base_dir, domain_coords=coords)
    else:
        domain_name = domain
        retrieve_era5(year, month, source, base_dir, domain_name=domain_name)
