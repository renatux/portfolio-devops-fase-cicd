# infra/core/main.tf
# Recursos COMPARTILHADOS entre todos os ambientes (dev, staging, prod).
# O ECR fica fora do modulo por ambiente porque e um so para os tres:
# as imagens se distinguem pela TAG (dev-<sha>, prod-<sha>), nao pelo repo.
#
# O repositorio webportfolio ja existe na conta. Na PRIMEIRA execucao, rode:
#   terraform import aws_ecr_repository.ecr_portfolio webportfolio
# Depois disso, o apply normal passa a gerenciar normalmente.

resource "aws_ecr_repository" "ecr_portfolio" {
  name                 = "webportfolio"
  image_tag_mutability = "IMMUTABLE"

  tags = {
    Name        = "webportfolio"
    Provisioned = "Terraform"
    Cliente     = "portfoliozzz"
  }
}