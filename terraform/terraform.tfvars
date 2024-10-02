vpc_id                  = "vpc-1234567890abcdef0"
subnet_ids              = ["subnet-1234567890abcdef0", "subnet-0987654321fedcba0"]
acm_certificate_arn     = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
domain_name             = "yourdomain.com"
route53_zone_id         = "Z1234567890ABCDEF"
alb_ingress_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]  # Replace with your desired CIDR blocks