terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }

  # Configuración parcial: bucket/key/region se pasan con -backend-config (ver backend.hcl.example).
  # use_lockfile requiere Terraform >= 1.10 (bloqueo nativo en S3, sin DynamoDB).
  backend "s3" {
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}
