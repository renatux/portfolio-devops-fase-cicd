resource "aws_iam_role" "ECR-EC2-Role" {
  name = "ECR-EC2-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name        = "ECR-EC2-Role"
    Provisioned = "Terraform"
    Cliente     = "portfoliozzz"
  }
}

# Instance profile: container que a EC2 usa para assumir a role.
# Criado explicitamente porque Terraform (aws_iam_role) NAO cria
# automaticamente, ao contrario do console AWS.
resource "aws_iam_instance_profile" "ecr_ec2" {
  name = "ECR-EC2-Role"
  role = aws_iam_role.ECR-EC2-Role.name
}
