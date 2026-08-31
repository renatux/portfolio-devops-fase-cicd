# infra/dev/backend.tf
terraform {
  backend "s3" {
    bucket  = "terraform-state-portfoliozzz"
    key     = "portfoliozzz/dev/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}