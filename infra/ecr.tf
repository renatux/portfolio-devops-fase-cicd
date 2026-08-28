#ECR Repository
resource "aws_ecr_repository" "ecr_portfolio" {
  name                 = "portfolio_prod"
  image_tag_mutability = "MUTABLE"
}