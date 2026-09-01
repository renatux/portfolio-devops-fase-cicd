# infra/staging/main.tf
variable "environment" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "vpc_id" {
  type = string
}

module "staging" {
  source        = "../modules/ec2"
  environment   = var.environment
  instance_type = var.instance_type
  vpc_id        = var.vpc_id
}

output "staging_public_ip" {
  value = module.staging.public_ip
}

output "staging_instance_id" {
  value = module.staging.instance_id
}