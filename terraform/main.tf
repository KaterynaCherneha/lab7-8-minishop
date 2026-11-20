terraform {
  required_version = ">=0.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "lab-tf-state-cherneha"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "lab-my-tf-lockid"
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

resource "aws_lightsail_container_service_deployment_version" "catalog_deployment" {
  container {
    container_name = "catalog-service"
    image          = "${var.REPOSITORY_URI}:latest"

    ports = {
      8001 = "HTTP"
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
}

output "lightsail_url" {
  value = aws_lightsail_container_service.catalog_service.url
}