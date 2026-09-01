# infra/dev/main.tf
variable "environment" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "vpc_id" {
  type = string
}

module "dev" {
  source        = "../modules/ec2"
  environment   = var.environment
  instance_type = var.instance_type
  vpc_id        = var.vpc_id
}

output "dev_public_ip" {
  value = module.dev.public_ip
}

output "dev_instance_id" {
  value = module.dev.instance_id
}