# Provider configuration
provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {}
variable "vpc_id" {}
variable "subnet_ids" { type = list(string) }
variable "ecs_task_cpu" {}
variable "ecs_task_memory" {}
variable "ecs_task_desired_count" {}
variable "postgres_port" {}
variable "langfuse_port" {}
variable "db_name" {}
variable "db_username" {}
variable "db_password" {}
variable "db_instance_class" {}
variable "elb_account_id" {}


resource "aws_ecr_repository" "lf_repo" {
  name                 = "lf-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "langfuse_cluster" {
  name = "langfuse-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "Langfuse ECS Cluster"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "langfuse_task" {
  family                   = "langfuse-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "langfuse"
      image = "${aws_ecr_repository.lf_repo.repository_url}:latest"
      portMappings = [
        {
          containerPort = var.langfuse_port
          hostPort      = var.langfuse_port
        }
      ]
      environment = [
        { name = "NEXTAUTH_URL", value = "http://${aws_lb.langfuse_alb.dns_name}"},
        { name = "DATABASE_URL", value = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.langfuse_db.endpoint}/${var.db_name}" }
      ]
      secrets = [
        { name = "NEXTAUTH_SECRET", valueFrom = "${data.aws_secretsmanager_secret.langfuse_secrets.arn}:langfuse_nextauth_secret::" },
        { name = "SALT", valueFrom = "${data.aws_secretsmanager_secret.langfuse_secrets.arn}:langfuse_salt::" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.langfuse_logs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "langfuse"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl http://localhost:${var.langfuse_port}/api/public/health"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 80
      }
    }
  ])

  tags = {
    Name = "Langfuse Task Definition"
  }
}

# ECS Service
resource "aws_ecs_service" "langfuse_service" {
  name            = "langfuse-service"
  cluster         = aws_ecs_cluster.langfuse_cluster.id
  task_definition = aws_ecs_task_definition.langfuse_task.arn
  launch_type     = "FARGATE"
  desired_count   = var.ecs_task_desired_count

  network_configuration {
    subnets          = var.subnet_ids
    assign_public_ip = false
    security_groups  = [aws_security_group.langfuse_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.langfuse_tg.arn
    container_name   = "langfuse"
    container_port   = var.langfuse_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = {
    Name = "Langfuse ECS Service"
  }
}

# Security Group
resource "aws_security_group" "langfuse_sg" {
  name        = "langfuse-sg"
  description = "Security group for Langfuse ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.langfuse_port
    to_port         = var.langfuse_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Langfuse ECS Security Group"
  }
}

# Application Load Balancer
resource "aws_lb" "langfuse_alb" {
  name               = "langfuse-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.subnet_ids

  enable_deletion_protection = false

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "langfuse-alb"
    enabled = true
  }

  tags = {
    Name = "Langfuse ALB"
  }
}

resource "aws_lb_target_group" "langfuse_tg" {
  name        = "langfuse-tg"
  port        = var.langfuse_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "Langfuse Target Group"
  }
}

resource "aws_lb_listener" "langfuse_listener" {
  load_balancer_arn = aws_lb.langfuse_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.langfuse_tg.arn
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "langfuse-alb-sg"
  description = "Security group for Langfuse ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Langfuse ALB Security Group"
  }
}

# S3 bucket for ALB access logs
resource "aws_s3_bucket" "alb_logs" {
  bucket = "langfuse-alb-logs-sr"

  tags = {
    Name = "Langfuse ALB Logs"
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.elb_account_id}:root"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
      }
    ]
  })
}

# IAM Roles
resource "aws_iam_role" "ecs_execution_role" {
  name = "langfuse-ecs-execution-role-sr"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "Langfuse ECS Execution Role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Create a custom policy for ECR access
resource "aws_iam_policy" "ecr_access_policy" {
  name        = "ecr_access_policy"
  path        = "/"
  description = "IAM policy for ECR access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the ECR access policy to the ECS execution role
resource "aws_iam_role_policy_attachment" "ecs_ecr_policy_attachment" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecr_access_policy.arn
}

resource "aws_iam_role_policy" "secrets_access" {
  name = "secrets-access"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["secretsmanager:GetSecretValue"]
        Effect   = "Allow"
        Resource = data.aws_secretsmanager_secret.langfuse_secrets.arn
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_role" {
  name = "langfuse-ecs-task-role-sr"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "Langfuse ECS Task Role"
  }
}

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "langfuse_logs" {
  name              = "/ecs/langfuse"
  retention_in_days = 30

  tags = {
    Name = "Langfuse CloudWatch Logs"
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu_utilization" {
  alarm_name          = "langfuse-high-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS CPU utilization"
  alarm_actions       = [aws_sns_topic.langfuse_alerts.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.langfuse_cluster.name
    ServiceName = aws_ecs_service.langfuse_service.name
  }
}

# SNS Topic for Alarms
resource "aws_sns_topic" "langfuse_alerts" {
  name = "langfuse-alerts"

  tags = {
    Name = "Langfuse Alerts SNS Topic"
  }
}

# Output
output "langfuse_url" {
  value       = "http://${aws_lb.langfuse_alb.dns_name}"
  description = "The URL of the Langfuse application"
}

output "rds_endpoint" {
  value       = aws_db_instance.langfuse_db.endpoint
  description = "The connection endpoint for the RDS instance"
}

# RDS Instance
resource "aws_db_instance" "langfuse_db" {
  identifier           = "langfuse-db"
  engine               = "postgres"
  engine_version       = "13"
  instance_class       = var.db_instance_class
  allocated_storage    = 20
  db_name              = var.db_name
  username             = var.db_username
  password             = var.db_password
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.langfuse_db_subnet_group.name
  backup_retention_period = 7
  multi_az               = true
  storage_encrypted      = true

  tags = {
    Name = "Langfuse CORSA POC Database"
    Environment = "Dev"
  }
}

resource "aws_db_subnet_group" "langfuse_db_subnet_group" {
  name       = "langfuse-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "Langfuse DB subnet group"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "langfuse-rds-sg"
  description = "Security group for Langfuse RDS"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.langfuse_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Langfuse RDS Security Group"
  }
}

# AWS Secrets Manager for sensitive data
data "aws_secretsmanager_secret" "langfuse_secrets" {
  name = "langfuse-config"
}

data "aws_secretsmanager_secret_version" "current" {
  secret_id = data.aws_secretsmanager_secret.langfuse_secrets.id
}

locals {
  secrets = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)
}
