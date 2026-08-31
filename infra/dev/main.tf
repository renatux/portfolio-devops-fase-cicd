# infra/dev/main.tf
module "dev" {
  source       = "../modules/ec2"
  environment  = "dev"
  instance_type = "t3.micro"
  vpc_id      = "vpc-07a6e93cbfbf26de2"
}

output "dev_public_ip" {
  value = module.dev.public_ip
}

output "dev_instance_id" {
  value = module.dev.instance_id
}