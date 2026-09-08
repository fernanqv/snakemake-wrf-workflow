# Compilación de WRF con Spack

Este directorio contiene la configuración necesaria para compilar WRF y WPS en un cluster HPC usando Spack.

## Archivos de configuración

- **`environments.yaml`**: Define el ambiente de Spack con todas las dependencias necesarias (NetCDF, HDF5, MPI, etc.)
- **`compilers.yaml`**: Configuración de compiladores disponibles en el cluster
- **`packages.yaml`**: Opciones de compilación para paquetes específicos
- **`build-wrf-spack.sh`**: Script principal de compilación

## Requisitos previos

1. **Spack instalado en el cluster**
   ```bash
   # Verificar disponibilidad
   module avail spack
   # o
   which spack
   ```

2. **Módulos del cluster necesarios**
   - GCC >= 9.0 (o Intel, NVIDIA HPC SDK)
   - OpenMPI o MPICH
   - Posiblemente otros dependiendo de la instalación de Spack del cluster

## Pasos para compilar WRF

### 1. Preparación inicial

```bash
cd /path/to/snakemake-wrf-workflow

# Cargar Spack del cluster
module load spack

# Verificar versión de Spack
spack --version
```

### 2. Configurar el compilador

**Opción A: Si tu cluster usa módulos para compiladores**

```bash
# Cargar el compilador deseado
module load GCC/11.3.0  # Ajusta según tu cluster

# Detectar automáticamente
spack compiler find
```

**Opción B: Actualizar manualmente `spack/compilers.yaml`**

```bash
# Verificar compilers disponibles
spack compiler list

# Editar spack/compilers.yaml si es necesario
# Ajustar paths según tu cluster
```

### 3. Ejecutar la compilación

```bash
bash spack/build-wrf-spack.sh
```

Opciones de variables de entorno:
```bash
# Especificar versiones (opcional)
WRF_VERSION=4.4.1 WPS_VERSION=4.4 bash spack/build-wrf-spack.sh

# Con más trabajos paralelos
spack config set config:build_jobs=8
```

### 4. Verificar instalación

```bash
# Los binarios estaran aquí
ls -la compilation/WRF/main/
ls -la compilation/WPS/main/

# Cargar ambiente de WRF
source compilation/wrf_env.sh
```

## Uso con Snakemake

Una vez compilado, actualiza tu configuración de Snakemake para usar los binarios:

```yaml
# config/config.yaml
wrf_install_dir: /path/to/snakemake-wrf-workflow/compilation/WRF
wps_install_dir: /path/to/snakemake-wrf-workflow/compilation/WPS
```

## Solución de problemas

### Error: "spack: command not found"
```bash
# Cargar módulo de spack
module load spack

# O inicializar desde instalación local
. /path/to/spack/share/spack/setup-env.sh
```

### Error de compilador no encontrado
```bash
# Ver compiladores disponibles
spack compiler list

# Detectar automáticamente nuevos
spack compiler find
```

### Limpiar ambiente de Spack (si hay errores)
```bash
# Desactivar ambiente actual
spack env deactivate

# Eliminar ambiente
spack env remove snakemake-wrf-workflow/spack/env

# Reinttentar
bash spack/build-wrf-spack.sh
```

## Información adicional

- [Documentación oficial de Spack](https://spack.readthedocs.io/)
- [Receta de WRF en Spack](https://github.com/spack/spack/tree/develop/var/spack/repos/builtin/packages)
- Para clusters específicos, consulta tu administrador de sistemas

## Notas del cluster

- **Compiler**: Ajusta en `spack/compilers.yaml` según tu cluster
- **MPI**: La configuración por defecto usa OpenMPI, cámbialo en `environments.yaml` si necesitas MPICH
- **Paths**: Modifica según estructura de tu cluster
