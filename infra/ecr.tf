#ECR Repository
resource "aws_ecr_repository" "ecr_portfolio" {
  name                 = "webportfolio"
  image_tag_mutability = "MUTABLE"
}