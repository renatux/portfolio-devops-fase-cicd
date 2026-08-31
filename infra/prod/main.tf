# infra/prod/main.tf
module "prod" {
  source       = "../modules/ec2"
  environment  = "prod"
  instance_type = "t3.micro"
}