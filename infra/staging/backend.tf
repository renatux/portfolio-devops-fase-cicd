# infra/staging/backend.tf
terraform {
  backend "s3" {
    bucket  = "terraform-state-portfoliozzz"
    key     = "portfoliozzz/staging/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}