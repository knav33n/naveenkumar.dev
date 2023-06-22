terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.61.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "2.3.0"
    }
  }

  backend "s3" {
    bucket = "naveenkumar.dev-terraform-state"
    key    = "naveenkumar.dev-terraform-state-key"
    region = "us-east-1"
  }
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}