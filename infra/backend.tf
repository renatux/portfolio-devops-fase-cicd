# state.tf
terraform {
  backend "s3" {
    bucket  = "terraform-state-portfoliozzz"
    key     = "portfoliozzz/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    use_lockfile = true

  }
}
