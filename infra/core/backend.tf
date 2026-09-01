# infra/core/backend.tf
# State DEDICADO aos recursos compartilhados (ECR), uma unica vez.
terraform {
  backend "s3" {
    bucket       = "terraform-state-portfoliozzz"
    key          = "portfoliozzz/core/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}