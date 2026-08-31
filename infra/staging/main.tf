# infra/staging/main.tf
module "staging" {
  source       = "../modules/ec2"
  environment  = "staging"
  instance_type = "t3.micro"
}