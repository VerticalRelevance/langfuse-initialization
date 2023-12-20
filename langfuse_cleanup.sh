#!/bin/bash

# Stop the Docker containers
echo "Stopping Langfuse and PostgreSQL containers..."
docker stop langfuse postgres-langfuse

# Remove the Docker containers
echo "Removing Langfuse and PostgreSQL containers..."
docker rm langfuse postgres-langfuse

# Optional: Remove the Docker images
# Uncomment the following lines if you want to remove the images as well
# echo "Removing Docker images..."
# docker rmi ghcr.io/langfuse/langfuse:latest postgres

# Optional: Remove the Docker volume for PostgreSQL
# Uncomment the following line if you want to remove the volume
# echo "Removing PostgreSQL Docker volume..."
# docker volume rm postgres-langfuse-data

echo "Cleanup completed."
