# infra/prod/main.tf
variable "environment" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "vpc_id" {
  type = string
}

module "prod" {
  source        = "../modules/ec2"
  environment   = var.environment
  instance_type = var.instance_type
  vpc_id        = var.vpc_id
}

output "prod_public_ip" {
  value = module.prod.public_ip
}

output "prod_instance_id" {
  value = module.prod.instance_id
}