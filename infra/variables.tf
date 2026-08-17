variable "aws_region" {
  description = "AWS region everything deploys into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name prefixed onto resource names/tags."
  type        = string
  default     = "rfp-template"
}

variable "db_name" {
  description = "Postgres database name (matches local docker-compose)."
  type        = string
  default     = "app"
}

variable "db_username" {
  description = "Postgres master username (matches local docker-compose)."
  type        = string
  default     = "app"
}
