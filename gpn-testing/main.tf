provider "aws" {
  region = "us-east-1"
}

# Step 1: Create a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

# Step 2: Create Subnets
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"  # Adjust as necessary
  availability_zone = "us-east-1a"  # Adjust as necessary
}

# Step 3: Create a Security Group
resource "aws_security_group" "lambda_sg" {
  vpc_id = aws_vpc.my_vpc.id

  # Allow outbound traffic to DynamoDB
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all outbound traffic
    cidr_blocks = ["10.0.0.0/16"]  # Adjust to your VPC CIDR
  }

  # Allow inbound traffic from VPC (if needed)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all inbound traffic
    cidr_blocks = ["10.0.0.0/16"]  # Adjust to your VPC CIDR
  }
}

# Step 4: Create a Lambda Execution Role
resource "aws_iam_role" "lambda_role" {
  name               = "lambda_vpc_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Step 5: Attach Policy for DynamoDB Access
resource "aws_iam_policy" "dynamodb_policy" {
  name        = "DynamoDBAccess"
  description = "Policy for Lambda to access DynamoDB"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:ListTables",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_dynamodb_policy" {
  policy_arn = aws_iam_policy.dynamodb_policy.arn
  role       = aws_iam_role.lambda_role.name
}

# Attach Policies to the IAM Role
resource "aws_iam_policy" "lambda_vpc_permissions_policy" {
  name = "lambda_vpc_permissions_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action   = "logs:*",
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Attach the policy to the Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_vpc_permissions" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_vpc_permissions_policy.arn
}

# Step 6: Create the Lambda Function
resource "aws_lambda_function" "my_lambda" {
  function_name = "ddb-test-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"  # Update based on your code structure
  runtime       = "python3.9"  # Specify the Python runtime
  
  # Assuming the source code is in a .zip file in the current directory
  filename      = "lambda_function.zip"
  
  vpc_config {
    subnet_ids          = [aws_subnet.private_subnet.id]
    security_group_ids  = [aws_security_group.lambda_sg.id]
  }
}


# Step 7: Create a VPC Endpoint for DynamoDB
resource "aws_vpc_endpoint" "dynamodb_endpoint" {
  vpc_id       = aws_vpc.my_vpc.id
  service_name = "com.amazonaws.us-east-1.dynamodb"
  route_table_ids = [aws_vpc.my_vpc.default_route_table_id]
}

# Step 8: Output
output "lambda_function_name" {
  value = aws_lambda_function.my_lambda.function_name
}
