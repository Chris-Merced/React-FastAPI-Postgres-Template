terraform {
  required_version = ">= 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Local state for now (solo, fast-moving). Upgrade path to an S3 backend
  # (shared/locked state) is a one-block change + `terraform init
  # -migrate-state` when this becomes a team project.
}
