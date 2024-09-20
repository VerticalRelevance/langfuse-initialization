#!/bin/bash

# Set strict mode for better error handling
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

# Function to load configuration from AWS Secrets Manager
load_config_from_aws_secrets() {
    local secret_name="langfuse-config"
    local region="us-east-2"  # Replace with your AWS region

    # Retrieve the secret string from AWS Secrets Manager
    secret=$(aws secretsmanager get-secret-value --secret-id "$secret_name" --region "$region" --query SecretString --output text)

    # Parse the JSON and set variables
    POSTGRES_PORT=$(echo "$secret" | jq -r '.postgres_port')
    LANGFUSE_PORT=$(echo "$secret" | jq -r '.langfuse_port')
    VPC_ID=$(echo "$secret" | jq -r '.aws_vpc_id')
    SUBNET_IDS=$(echo "$secret" | jq -r '.aws_subnet_ids')
    DB_NAME=$(echo "$secret" | jq -r '.postgres_db_name')
    DB_USERNAME=$(echo "$secret" | jq -r '.postgres_username')
    DB_PASSWORD=$(echo "$secret" | jq -r '.postgres_password')
    DB_INSTANCE_CLASS=$(echo "$secret" | jq -r '.postgres_instance_class')
}

# Load configuration from AWS Secrets Manager
load_config_from_aws_secrets

# Create a Terraform variables file (without sensitive information)
# ELB account id used is for us-east-2
cat << EOF > "$TERRAFORM_DIR/terraform.tfvars"
postgres_port = $POSTGRES_PORT
langfuse_port = $LANGFUSE_PORT
aws_region = "us-east-2"
vpc_id = "$VPC_ID"
subnet_ids = ["${SUBNET_IDS//,/\",\"}"]
ecs_task_cpu = "1024"
ecs_task_memory = "2048"
ecs_task_desired_count = 2
db_name = "$DB_NAME"
db_username = "$DB_USERNAME"
db_password = "$DB_PASSWORD"
db_instance_class = "$DB_INSTANCE_CLASS"
elb_account_id = "033677994240"
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
