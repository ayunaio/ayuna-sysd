# Ayuna Sysd

System services to run Ayuna applications. Please refer to the documentation of each service to understand the specific licensing terms. Current selection contains services which are licensed using one of the open source licenses.

## Setup docker artifacts

```bash
## Run the setup script to create volumes, network and database
bash docker-setup.sh

## To force clean and create containers and volumes afresh
bash docker-setup.sh --force-clean
```

## Create environment files

The project uses jinja2 templates to create environment files, dynamically. Follow the steps below to create require environment files.

```bash
## Prepare env template data file
cp env_data.yaml.sample .env_data.yaml

## Edit the file '.env_data.yaml' and provide required values for various secrets by replacing the place-holder values.

## Install python dependencies using 'uv'
uv sync --active --refresh

## Finally, generate the env files. It checks for .env_data.yaml file under the script folder by default.
python env-gen.py

## You can also keep custom env-data file(s) outside and pass them as command line arguments. If none passed, .env_data.yaml is the default.
python env-gen.py <path-to-your-env-data-file>
```

## Run the services

The services can be started using `docker compose up -d` and stopped using `docker compose down`.

> **NOTE**: *Individual system services come with their respective licenses. This setup is only to run them as docker containers for Ayuna application development.*
