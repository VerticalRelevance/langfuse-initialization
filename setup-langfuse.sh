#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Function to check and install yq
install_yq() {
    if ! command -v yq &> /dev/null; then
        echo "yq could not be found, attempting to install..."
        sudo apt-get update
        sudo apt-get install -y python3-pip
        pip3 install yq
    fi
}

# Function to check and install Python
install_python() {
    if ! command -v python3 &> /dev/null; then
        echo "Python could not be found, attempting to install..."
        sudo apt-get update
        sudo apt-get install -y python3
    fi
}

# Install yq and Python if they are not installed
install_python
install_yq

# Function to load configuration from YAML file
load_config_from_yaml() {
    config_file=$1

    full_config_path="$SCRIPT_DIR/$config_file"

    if [ ! -f "$full_config_path" ]; then
        echo "Configuration file not found: $full_config_path"
        exit 1
    fi

    POSTGRES_USER=$(yq e '.postgres.user' "$full_config_path")
    echo "POSTGRES_USER: $POSTGRES_USER"
    POSTGRES_PASSWORD=$(yq e '.postgres.password' "$full_config_path")
    echo "POSTGRES_PASSWORD: $POSTGRES_PASSWORD"
    POSTGRES_DB=$(yq e '.postgres.dbname' "$full_config_path")
    echo "POSTGRES_DB: $POSTGRES_DB"
    POSTGRES_PORT=$(yq e '.postgres.port' "$full_config_path")
    echo "POSTGRES_PORT: $POSTGRES_PORT"
    LANGFUSE_HOST=$(yq e '.langfuse.host' "$full_config_path")
    echo "LANGFUSE_HOST: $LANGFUSE_HOST"
    NEXTAUTH_URL=$(yq e '.langfuse.nextauth_url' "$full_config_path")
    echo "NEXTAUTH_URL: $NEXTAUTH_URL"
}

# Check if arguments are provided
if [ $# -eq 0 ]; then
    echo "No arguments provided, expecting yaml file."
    read -p "Enter path to config file: " config_path
    load_config_from_yaml "$config_path"
else
    POSTGRES_USER=$1
    POSTGRES_PASSWORD=$2
    POSTGRES_DB=$3
    POSTGRES_PORT=$4
    LANGFUSE_HOST=$5
    NEXTAUTH_URL=$6
fi

# Check for Docker and install if not present
if ! command -v docker &> /dev/null
then
    echo "Docker could not be found, attempting to install..."
    sudo apt-get update
    sudo apt-get install -y docker.io
    # Start Docker if it's not running
    sudo systemctl start docker
    sudo systemctl enable docker
fi

# Check for openssl and install if not present
if ! command -v openssl &> /dev/null
then
    echo "openssl could not be found, attempting to install..."
    sudo apt-get update
    sudo apt-get install -y openssl
fi

# Generate secrets using openssl
NEXTAUTH_SECRET=$(openssl rand -base64 32)
SALT=$(openssl rand -base64 32)

echo "Generated NEXTAUTH_SECRET: $NEXTAUTH_SECRET"
echo "Generated SALT: $SALT"

# Pull the latest Docker images
docker pull postgres
docker pull ghcr.io/langfuse/langfuse:latest

# Create a Docker network if it doesn't exist
docker network ls | grep -q langfuse-network || docker network create langfuse-network

# Start the Postgres container
docker run --name postgres-langfuse --network langfuse-network  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=postgres -p $POSTGRES_PORT:5432 -v postgres-langfuse-data:/var/lib/postgresql/data -d postgres

LANGFUSE_HOST=postgres-langfuse

# Wait for a moment to ensure PostgreSQL is fully up and running
sleep 30

# Start the Langfuse container
docker run --name langfuse --network langfuse-network \
    -e DATABASE_URL=postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@postgres-langfuse:5432/$POSTGRES_DB \
    -e NEXTAUTH_URL=http://localhost:3000 \
    -e NEXTAUTH_SECRET=$NEXTAUTH_SECRET \
    -e SALT=$SALT \
    -p 3000:3000 \
    -d ghcr.io/langfuse/langfuse:latest



# Wait for a moment to ensure containers are starting
sleep 30

# Check if the PostgreSQL container is running
if docker ps | grep -q postgres-langfuse; then
    echo "PostgreSQL container is running."
else
    echo "Error: PostgreSQL container failed to start."
    exit 1
fi

# Check if the Langfuse container is running
if docker ps | grep -q langfuse; then
    echo "Langfuse container is running."
else
    echo "Error: Langfuse container failed to start."
    exit 1
fi

# Simple health check for Langfuse
if curl --fail -s http://localhost:3000/ > /dev/null; then
    echo "Langfuse is up and running on port 3000."
else
    echo "Error: Langfuse is not responding on port 3000."
    exit 1
fi

echo "Setup completed successfully."