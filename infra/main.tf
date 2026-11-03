terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
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