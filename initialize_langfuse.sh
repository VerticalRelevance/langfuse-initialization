#!/bin/bash

# Function to load configuration from YAML file
load_config_from_yaml() {
    config_file=$1
    POSTGRES_USER=$(yq e '.postgres.user' $config_file)
    POSTGRES_PASSWORD=$(yq e '.postgres.password' $config_file)
    POSTGRES_DB=$(yq e '.postgres.dbname' $config_file)
    POSTGRES_PORT=$(yq e '.postgres.port' $config_file)
    LANGFUSE_HOST=$(yq e '.langfuse.host' $config_file)
    NEXTAUTH_URL=$(yq e '.langfuse.nextauth_url' $config_file)
}

# Check if arguments are provided
if [ $# -eq 0 ]; then
    echo "No arguments provided, expecting yaml file."
    read -p "Enter path to config file: " config_path
    load_config_from_yaml $config_path
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

# Start the Postgres container
docker run --name postgres-langfuse -e POSTGRES_USER=$POSTGRES_USER -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD -e POSTGRES_DB=$POSTGRES_DB -p $POSTGRES_PORT:5432 -v postgres-langfuse-data:/var/lib/postgresql/data -d postgres

# Wait for a moment to ensure PostgreSQL is fully up and running
sleep 10

# Start the Langfuse container
docker run --name langfuse \
    -e DATABASE_URL=postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@$LANGFUSE_HOST:$POSTGRES_PORT/$POSTGRES_DB \
    -e NEXTAUTH_URL=$NEXTAUTH_URL \
    -e NEXTAUTH_SECRET=$NEXTAUTH_SECRET \
    -e SALT=$SALT \
    -p 8084:3000 \
    -a STDOUT \
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
if curl --fail -s http://localhost:8084/ > /dev/null; then
    echo "Langfuse is up and running on port 8084."
else
    echo "Error: Langfuse is not responding on port 8084."
    exit 1
fi

echo "Setup completed successfully."