resource "aws_iam_role" "ECR-EC2-Role" {
  name = "ECR-EC2-Role-${var.environment}"

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
# automaticamente, ao contrario do console AWS
resource "aws_iam_instance_profile" "ecr_ec2" {
  name = "ECR-EC2-Role-${var.environment}"
  role = aws_iam_role.ECR-EC2-Role.name
}

# SSM: permite o deploy via Run Command sem abrir a porta 22
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ECR-EC2-Role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ECR pull com menor privilegio: somente o repositorio webportfolio
resource "aws_iam_role_policy" "ecr_pull_webportfolio" {
  name = "ECR-Pull-Webportfolio"
  role = aws_iam_role.ECR-EC2-Role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "LoginNoECR"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "PullSomenteDoWebportfolio"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = "arn:aws:ecr:us-east-1:614879421397:repository/${var.ecr_repository_name}"
      },
    ]
  })
}