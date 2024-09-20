# docker pull ghcr.io/langfuse/langfuse:latest

#!/usr/bin/env bash
# AWS Region
AWS_REGION="us-east-2"
# AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
# AWS ECR Login
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

## ECR Repository Name
REPO_NAME="lf-repo"

# Tag Docker Image
docker tag ghcr.io/langfuse/langfuse:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:latest
# Push Docker Image to ECR
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:latest
echo "Docker image pushed to ECR: $REPO_NAME"