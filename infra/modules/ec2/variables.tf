variable "environment" {
  description = "Ambiente de destino (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment deve ser dev, staging ou prod."
  }
}

variable "instance_type" {
  description = "Tipo da instância EC2"
  type        = string
  default     = "t3.micro"
}

variable "vpc_id" {
  description = "ID da VPC onde o Security Group sera criado"
  type        = string
}

variable "ecr_repository_name" {
  description = "Nome do repositorio ECR compartilhado (pull da imagem)"
  type        = string
  default     = "webportfolio"
}