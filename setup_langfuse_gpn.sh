#!/bin/bash

# Set strict mode for better error handling
set -euo pipefail

# Function to install a required package
install_package() {
    local package=$1
    if ! command -v "$package" &> /dev/null; then
        echo "$package could not be found, attempting to install..."
        sudo apt-get update
        sudo apt-get install -y "$package"
    fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

# Install required packages
install_package python3
install_package pip3
install_package awscli
install_package jq
install_package docker
install_package terraform

# Function to load configuration from AWS Secrets Manager
load_config_from_aws_secrets() {
    local secret_name="langfuse-config"
    local region="us-east-1"  # Replace with your AWS region

    # Retrieve the secret string from AWS Secrets Manager
    secret=$(aws secretsmanager get-secret-value --secret-id "$secret_name" --region "$region" --query SecretString --output text)

    # Parse the JSON and set variables
    POSTGRES_PORT=$(echo "$secret" | jq -r '.postgres.port')
    LANGFUSE_HOST=$(echo "$secret" | jq -r '.langfuse.host')
    LANGFUSE_PORT=$(echo "$secret" | jq -r '.langfuse.port')
    NEXTAUTH_URL=$(echo "$secret" | jq -r '.langfuse.nextauth_url')
    HARBOR_REGISTRY=$(echo "$secret" | jq -r '.harbor.registry')
    HARBOR_PROJECT=$(echo "$secret" | jq -r '.harbor.project')
    HARBOR_USERNAME=$(echo "$secret" | jq -r '.harbor.username')
    HARBOR_PASSWORD=$(echo "$secret" | jq -r '.harbor.password')
    VPC_ID=$(echo "$secret" | jq -r '.aws.vpc_id')
    SUBNET_IDS=$(echo "$secret" | jq -r '.aws.subnet_ids | join(",")')
    DB_NAME=$(echo "$secret" | jq -r '.postgres.db_name')
    DB_USERNAME=$(echo "$secret" | jq -r '.postgres.username')
    DB_PASSWORD=$(echo "$secret" | jq -r '.postgres.password')
    ACM_CERTIFICATE_ARN=$(echo "$secret" | jq -r '.aws.acm_certificate_arn')
    DB_INSTANCE_CLASS=$(echo "$secret" | jq -r '.postgres.instance_class')
}

# Load configuration from AWS Secrets Manager
load_config_from_aws_secrets

# Pull the latest Langfuse Docker image
docker pull ghcr.io/langfuse/langfuse:latest

# Tag the image for Harbor
HARBOR_IMAGE_TAG="${HARBOR_REGISTRY}/${HARBOR_PROJECT}/langfuse:latest"
docker tag ghcr.io/langfuse/langfuse:latest "$HARBOR_IMAGE_TAG"

# Login to Harbor
echo "$HARBOR_PASSWORD" | docker login "$HARBOR_REGISTRY" -u "$HARBOR_USERNAME" --password-stdin

# Push the image to Harbor
docker push "$HARBOR_IMAGE_TAG"

# Create a Terraform variables file (without sensitive information)
cat << EOF > "$TERRAFORM_DIR/terraform.tfvars"
postgres_port = $POSTGRES_PORT
langfuse_host = "$LANGFUSE_HOST"
langfuse_port = $LANGFUSE_PORT
nextauth_url = "$NEXTAUTH_URL"
aws_region = "us-east-1"
vpc_id = "$VPC_ID"
subnet_ids = ["${SUBNET_IDS//,/\",\"}"]
ecs_task_cpu = "1024"
ecs_task_memory = "2048"
ecs_task_desired_count = 2
harbor_image_url = "$HARBOR_IMAGE_TAG"
db_name = "$DB_NAME"
db_username = "$DB_USERNAME"
db_password = "$DB_PASSWORD"
acm_certificate_arn = "$ACM_CERTIFICATE_ARN"
db_instance_class = "$DB_INSTANCE_CLASS"
EOF

# Change to the Terraform directory
cd "$TERRAFORM_DIR"

# Initialize Terraform
terraform init

# Plan Terraform changes
terraform plan -out=tfplan

# Apply Terraform changes
terraform apply tfplan

echo "Terraform apply completed. Check AWS Console for resources."
