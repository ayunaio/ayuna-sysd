#!/bin/bash -e
## Script to setup Docker environment for Ayuna local development

## Set line coloring
TRML_HL='\033[1;35m'
TRML_NC='\033[0m'

echo_info() {
    echo -e "${TRML_HL}$1${TRML_NC}"
}

echo_error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd "$SCRIPT_DIR" || exit 1

## Check if Docker is installed
if ! command -v docker &>/dev/null; then
    echo_error "Docker could not be found. Please install Docker first."
    exit 1
else
    echo_info "Found Docker installation."
    echo_info "Docker version: $(docker --version)"
    echo_info "Docker info: $(docker info --format '{{.ServerVersion}}')"
fi

## Check if Docker Compose is installed
if [ ! -f "docker-compose.yaml" ]; then
    echo_error "docker-compose.yaml file not found in the current directory."
    exit 1
fi

## Check for docker environment variables
if [ ! -f "env/ayuna-sysd.env" ]; then
    echo_error "env/ayuna-sysd.env file not found in the current directory."
    exit 1
else
    echo_info "Loading environment variables from env/ayuna-sysd.env"
    set -o allexport
    source env/ayuna-sysd.env
    set +o allexport
fi

## Add an optional argument to force-clean the Docker environment. Call the command with --force-clean
force_clean="false"

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo_info "Usage: $0 [--force-clean]"
    echo_info "Options:"
    echo_info "  --force-clean   Force clean the Docker environment (remove all containers and volumes)."
    echo_info "  --help, -h      Show this help message."
    exit 0
fi

if [[ "$1" == "--force-clean" ]]; then
    force_clean="true"
    echo_info "Force clean mode enabled. All existing containers and volumes will be removed."
fi

## Define the Docker network and volumes
network_name="ayuna-net"

backend_volumes=(
    "ayuna_data"
    "postgres_data"
    "neo4j_data"
    "neo4j_plugins"
    "neo4j_config"
    "neo4j_logs"
    "valkey_data"
    "seaweed_data"
    "nats_data"
    "otel_data"
)

sql_dbs=(
    "ayuna_db"
)

## Stop all running containers before setting up the environment
echo_info "Stopping all running containers..."
docker compose down 2>/dev/null && sync

## Remove dangling images
dangling_images=$(docker images -q --filter "dangling=true")

if [ -n "${dangling_images}" ]; then
    echo_info "Removing dangling docker images..."
    docker rmi ${dangling_images} && sync
fi

if [[ "$force_clean" == "true" ]]; then
    echo_info "Force clean mode enabled. Removing volumes..."

    for volume in "${backend_volumes[@]}"; do
        if docker volume ls | grep -q "${volume}"; then
            echo_info "Removing Docker volume: ${volume}"
            docker volume rm "${volume}" 2>&1 >/dev/null
        else
            echo_info "Docker volume ${volume} does not exist."
        fi
    done

    sleep 3
fi

## Check if network exists; if not, create it
if ! docker network ls | grep -q "$network_name"; then
    echo_info "Creating Docker network: $network_name"
    docker network create "$network_name" 2>&1 >/dev/null
else
    echo_info "Docker network $network_name already exists."
fi

## Check if volumes exist; if not, create them
echo_info "Checking and creating volumes..."

for volume in "${backend_volumes[@]}"; do
    if ! docker volume ls | grep -q "$volume"; then
        echo_info "Creating Docker volume: $volume"
        docker volume create "$volume" 2>&1 >/dev/null
    else
        echo_info "Docker volume $volume already exists."
    fi
done

## Download https://dist.dozerdb.org/plugins/open-gds/open-gds-2.12.0.jar and add it to the neo4j_plugins volume
neo4j_src_dir="env/neo4j"
mkdir -p ${neo4j_src_dir}/plugins

echo_info "Copying plugins from ${neo4j_src_dir}/plugins to Docker volume neo4j_plugins"
if [ ! -f "${neo4j_src_dir}/plugins/open-gds-2.12.0.jar" ]; then
    echo_info "Downloading open-gds-2.12.0.jar from https://dist.dozerdb.org/plugins/open-gds/open-gds-2.12.0.jar"
    mkdir -p ${neo4j_src_dir}/plugins
    curl -o ${neo4j_src_dir}/plugins/open-gds-2.12.0.jar https://dist.dozerdb.org/plugins/open-gds/open-gds-2.12.0.jar
else
    echo "Using cached file ${neo4j_src_dir}/plugins/open-gds-2.12.0.jar"
fi

docker run --rm \
    -v neo4j_plugins:/plugins \
    -v ./${neo4j_src_dir}/plugins:/source \
    -v neo4j_config:/var/lib/neo4j/conf \
    -v neo4j_logs:/var/lib/neo4j/logs \
    -v ayuna_data:/ayuna/data \
    -v ./scripts/neo4j-init.sh:/tmp/neo4j-init.sh \
    alpine sh -c "sh /tmp/neo4j-init.sh; chown -R 1001:1001 /ayuna/data" && sync && echo_info "Ayuna volume setup completed."

## Create databases under postgres server and add pgvector extension in each.
## Start the server if not already running and check for databases before creating them.
if ! docker ps -a | grep -q "ayuna-postgres"; then
    echo_info "Starting PostgreSQL server ayuna-postgres"
    docker run -d --name ayuna-postgres --network "${network_name}" \
        -e POSTGRES_USER=${POSTGRES_USER} \
        -e POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
        -v postgres_data:/var/lib/postgresql/data:Z \
        -p 5432:5432 \
        pgvector/pgvector:pg17 2>&1 >/dev/null
else
    echo_info "PostgreSQL server ayuna-postgres is already running."
fi

## Wait for PostgreSQL server to be ready
echo_info "Waiting for PostgreSQL server ayuna-postgres to be ready..."
while ! docker exec ayuna-postgres pg_isready -U ${POSTGRES_USER} 2>&1 >/dev/null; do
    echo_info "PostgreSQL server is not ready yet. Waiting..."
    sleep 5
done

echo_info "PostgreSQL server ayuna-postgres is ready."
## Check if databases exist; if not, create them
for db in "${sql_dbs[@]}"; do
    if docker exec -it -e PGPASSWORD=${POSTGRES_PASSWORD} ayuna-postgres psql -U ${POSTGRES_USER} ${db} -c '\q' 2>&1 >/dev/null; then
        echo_info "Database $db already exists."
    else
        echo_info "Creating database $db in PostgreSQL server ayuna-postgres"
        docker exec -it -e PGPASSWORD=${POSTGRES_PASSWORD} ayuna-postgres psql -U ${POSTGRES_USER} -c "CREATE DATABASE $db;" 2>&1 >/dev/null
        echo_info "Creating pgvector extension in database $db"
        docker exec -it -e PGPASSWORD=${POSTGRES_PASSWORD} ayuna-postgres psql -U ${POSTGRES_USER} -d "$db" -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>&1 >/dev/null
    fi
done

## Stop and remove the PostgreSQL server ayuna-postgres
sleep 5 && sync
docker stop ayuna-postgres >/dev/null &&
    docker rm ayuna-postgres >/dev/null &&
    echo_info "PostgreSQL server ayuna-postgres has been setup and stopped"

echo_info "Docker setup completed successfully."

echo_info "You can now run 'docker compose up' to start the services."
echo_info "If you want to run the services in detached mode, use 'docker compose up -d'."
echo_info "To stop the services, use 'docker compose down'."
echo_info "To view the logs, use 'docker compose logs -f'."
