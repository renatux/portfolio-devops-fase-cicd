# infra/prod/backend.tf
terraform {
  backend "s3" {
    bucket  = "terraform-state-portfoliozzz"
    key     = "portfoliozzz/prod/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}