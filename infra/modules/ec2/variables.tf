variable "environment" {
    description = "Ambiente de destino (dev, staging, prod)"
    type        = string
  
}

variable "instance_type" {
    description = "Tipo da instância EC2"
    type        = string
    default     = "t3.micro"
}