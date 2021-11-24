terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  required_version = "1.0.9"
}

provider "aws" {
  region                  = var.region
  shared_credentials_file = "~/.aws/credentials"
  profile                 = "drpersonal"
  default_tags {
    tags = {
      "Environment" = var.env
      "Service"     = "Infrastructure"
      "Terraform"   = "true"
    }
  }
}
