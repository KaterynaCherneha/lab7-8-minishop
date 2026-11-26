terraform {
  required_version = ">=0.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket       = "lab-tf-state-cherneha"
    key          = "terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
  }
}

# Configure the AWS provider
provider "aws" {
  region = "eu-central-1"
}

variable "REPOSITORY_URI" {
  type = string
}

resource "aws_lightsail_container_service" "catalog_service" {
  name  = "catalog-service"
  power = "nano"
  scale = 1

  private_registry_access {
    ecr_image_puller_role {
      is_active = true
    }
  }

  tags = {
    version = "1.0.0"
  }
}

resource "aws_ecr_repository_policy" "allow_lightsail" {
  repository = split("/", var.REPOSITORY_URI)[1]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLightsailPull"
        Effect = "Allow"
        Principal = {
          AWS = aws_lightsail_container_service.catalog_service.private_registry_access[0].ecr_image_puller_role[0].principal_arn
        }
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

resource "aws_lightsail_container_service_deployment_version" "catalog_deployment" {
  container {
    container_name = "catalog-service"
    image          = "${var.REPOSITORY_URI}:latest"

    environment = {
      REDIS_HOST = "localhost"
      REDIS_PORT = "6379"
    }

    ports = {
      8001 = "HTTP"
    }
  }

  container {
    container_name = "redis"
    image          = "redis:7-alpine"

    ports = {
      6379 = "TCP"
    }
  }

  public_endpoint {
    container_name = "catalog-service"
    container_port = 8001

    health_check {
      healthy_threshold   = 2
      unhealthy_threshold = 2
      timeout_seconds     = 2
      interval_seconds    = 5
      path                = "/health"
      success_codes       = "200-499"
    }
  }

  service_name = aws_lightsail_container_service.catalog_service.name
  depends_on   = [aws_ecr_repository_policy.allow_lightsail]
}

output "lightsail_url" {
  value = aws_lightsail_container_service.catalog_service.url
}