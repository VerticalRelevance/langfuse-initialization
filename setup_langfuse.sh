#!/bin/bash

# Set strict mode for better error handling
set -euo pipefail

# Function to install a required package
install_package() {
    local package=$1
    if ! command -v "$package" &> /dev/null; then
        echo "$package could not be found, attempting to install..."
        apt-get update
        apt-get install -y "$package"
    fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Install required packages
install_package python3
install_package pip3
install_package yq
install_package openssl

# Function to load configuration from YAML file
load_config_from_yaml() {
    local config_file="$SCRIPT_DIR/$1"
    if [ ! -f "$config_file" ]; then
        echo "Configuration file not found: $config_file"
        exit 1
    fi

    POSTGRES_USER=$(yq e '.postgres.user' "$config_file")
    POSTGRES_PASSWORD=$(yq e '.postgres.password' "$config_file")
    POSTGRES_DB=$(yq e '.postgres.dbname' "$config_file")
    POSTGRES_PORT=$(yq e '.postgres.port' "$config_file")
    LANGFUSE_HOST=$(yq e '.langfuse.host' "$config_file")
    LANGFUSE_PORT=$(yq e '.langfuse.port' "$config_file")
    NEXTAUTH_URL=$(yq e '.langfuse.nextauth_url' "$config_file")
}

# Check for Docker and install if not present
if ! command -v docker &> /dev/null; then
    echo "Docker could not be found, attempting to install..."
    apt-get update
    apt-get install -y docker.io
fi

# Load configuration
if [ $# -eq 0 ]; then
    default_config_path="$SCRIPT_DIR/config.yaml"
    if [ -f "$default_config_path" ]; then
        echo "Using default config file: $default_config_path"
        load_config_from_yaml "config.yaml"
    else
        echo "Default config file not found."
        read -rp "Enter path to config file: " config_path
        load_config_from_yaml "$config_path"
    fi
else
    POSTGRES_USER=$1
    POSTGRES_PASSWORD=$2
    POSTGRES_DB=$3
    POSTGRES_PORT=$4
    LANGFUSE_HOST=$5
    LANGFUSE_HOST=$6
    NEXTAUTH_URL=$7
fi

# Generate secrets
NEXTAUTH_SECRET=$(openssl rand -base64 32)
SALT=$(openssl rand -base64 32)

# Pull the latest Docker images
docker pull postgres
docker pull ghcr.io/langfuse/langfuse:latest

# Create a Docker network if it doesn't exist
docker network ls | grep -q langfuse-network || docker network create langfuse-network

# Start the Postgres container
docker run --name postgres-langfuse --network langfuse-network -e POSTGRES_USER="$POSTGRES_USER" -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" -e POSTGRES_DB="$POSTGRES_DB" -p "$POSTGRES_PORT":5432 -v postgres-langfuse-data:/var/lib/postgresql/data -d postgres

# Wait for PostgreSQL to be fully up and running
sleep 30

# Start the Langfuse container
docker run --name langfuse --network langfuse-network -e DATABASE_URL="postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@postgres-langfuse:5432/$POSTGRES_DB" -e NEXTAUTH_URL="$NEXTAUTH_URL:$LANGFUSE_PORT" -e NEXTAUTH_SECRET="$NEXTAUTH_SECRET" -e SALT="$SALT" -p "$LANGFUSE_PORT":3000 -d ghcr.io/langfuse/langfuse:latest

# Wait for containers to start
sleep 30

# Check containers' status
if docker ps | grep -q postgres-langfuse; then
    echo "PostgreSQL container is running."
else
    echo "Error: PostgreSQL container failed to start."
    exit 1
fi

if docker ps | grep -q langfuse; then
    echo "Langfuse container is running."
else
    echo "Error: Langfuse container failed to start."
    exit 1
fi

# Health check for Langfuse
if curl --fail -s http://localhost:"$LANGFUSE_PORT" > /dev/null; then
    echo "Langfuse is up and running on port $LANGFUSE_PORT."
else
    echo "Error: Langfuse is not responding on port $LANGFUSE_PORT."
    exit 1
fi

echo "Setup completed successfully."
