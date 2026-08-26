# 🔄 Portfólio DevOps: Pipeline Terraform CI/CD com GitHub Actions

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?logo=githubactions&logoColor=white)](https://github.com/features/actions)
[![Terraform](https://img.shields.io/badge/Terraform-844FBA?logo=terraform&logoColor=white)](https://www.terraform.io)
[![OIDC](https://img.shields.io/badge/OIDC-0B6E4F?logo=openid&logoColor=white)](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
[![Amazon AWS](https://img.shields.io/badge/AWS-FF9900?logo=amazonaws&logoColor=white)](https://aws.amazon.com)

Pipeline de CI/CD que provisiona infraestrutura AWS com Terraform a partir do GitHub Actions, sem access keys: a autenticação é feita via OpenID Connect (OIDC), com a AWS confiando no token emitido pelo GitHub.

## Índice

1. [Sobre o Projeto](#1-sobre-o-projeto)
2. [Arquitetura](#2-arquitetura)
3. [Estrutura do Repositório](#3-estrutura-do-repositório)
4. [Pré-requisitos](#4-pré-requisitos)
5. [Configuração do OIDC na AWS](#5-configuração-do-oidc-na-aws)
6. [Como Usar](#6-como-usar)
7. [Permissões da Role](#7-permissões-da-role)
8. [Custo Estimado](#8-custo-estimado)
9. [Limpeza de Recursos](#9-limpeza-de-recursos)
10. [Troubleshooting](#10-troubleshooting)
11. [Referências](#11-referências)

---

## 1. Sobre o Projeto

O workflow `terraform.yaml` executa o ciclo completo do Terraform em uma instância `ubuntu-latest` do GitHub Actions:

1. Faz checkout do repositório.
2. Assume uma role IAM na AWS via OIDC (troca do token do GitHub por credenciais temporárias).
3. Executa `terraform init`, `terraform validate` e `terraform plan`.
4. Executa `terraform apply` ou `terraform destroy` apenas quando acionado explicitamente pelos inputs do workflow.

A infraestrutura gerenciada pelo código deste repositório provisiona, na região `us-east-1`:

- **EC2**: instância `t3.micro` (Amazon Linux 2023) servindo o site.
- **Security Group**: portas 22 (seu IP), 80 e 443 (público) e saída completa.
- **ECR**: repositório privado `portfolio_prod` para imagens de container.
- **IAM**: role `ECR-EC2-Role` + instance profile para a EC2 acessar o ECR.

O state do Terraform fica remoto no S3 (`terraform-state-portfoliozzz`), garantindo consistência e lock entre execuções.

---

## 2. Arquitetura

```
+---------------------+       +----------------------------+       +-------------------------+
| GitHub Actions      |       | AWS STS                    |       | Terraform (no runner)   |
| workflow_dispatch   | ----> | sts:AssumeRoleWithWebIdentity| ----> | init -> validate -> plan|
+---------------------+  JWT  +----------------------------+       | apply / destroy (inputs)|
        |                       |  role: GithubActionsRole          +-------------------------+
        |                       v                                            |
        |        +----------------------------+                             v
        +------> | OIDC Provider               |                  +--------------------------+
                 | token.actions.githubusercontent.com           | AWS (EC2, ECR, IAM, SG)   |
                 | + trust policy da role       |                | State remoto no S3        |
                 +----------------------------+                  +--------------------------+
```

Fluxo resumido: o GitHub emite um JWT assinado (com `sub` e `aud`), a AWS valida o token contra o provider OIDC e a trust policy da role, entrega credenciais temporárias e o Terraform opera os recursos.

---

## 3. Estrutura do Repositório

```
portfolio-devops-fase-cicd/
├── .github/workflows/
│   └── terraform.yaml       # Pipeline CI/CD (disparo manual)
├── backend.tf               # State remoto no S3 com lock
├── provider.tf              # Provider AWS (us-east-1)
├── ec2.tf                   # Instância EC2, Security Group e regras
├── ecr.tf                   # Repositório ECR portfolio_prod
├── role.tf                  # IAM role + instance profile da EC2
├── LICENSE                  # MIT
└── .gitignore               # Artefatos Terraform e do ambiente
```

---

## 4. Pré-requisitos

- Conta AWS com credenciais de administrador para a configuração inicial.
- Repositório no GitHub (este projeto).
- O S3 bucket do state (`terraform-state-portfoliozzz`) criado, com versionamento habilitado.
- OIDC configurado (seção abaixo).

---

## 5. Configuração do OIDC na AWS

### 5.1 Criar o provider OIDC

Console AWS → IAM → Identity providers → Add provider:

- **Provider type**: OpenID Connect
- **Provider URL**: `https://token.actions.githubusercontent.com`
- **Client ID**: `sts.amazonaws.com`
- Thumbprint: usar o gerado pela AWS no momento da criação.

Ou via CLI:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com
```

### 5.2 Criar a role e a trust policy

Console AWS → IAM → Roles → Create role → Custom trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:renatux*/*:*"
        }
      }
    }
  ]
}
```

**Atenção ao formato do `sub`**: o GitHub hoje emite o claim com os IDs numéricos embutidos, por exemplo:

```
repo:renatux@1243309/portfolio-devops-fase-cicd@1347478107:ref:refs/heads/main
```

Por isso o padrão `repo:renatux*/*:*` (com curingas após o usuário), em vez do formato antigo `repo:renatux/portfolio-devops-fase-cicd:*`, que não casa e derruba o pipeline com `Not authorized to perform sts:AssumeRoleWithWebIdentity`. Para ver os claims exatos do seu token, edite o campo `role-to-assume` do workflow com uma role válida e rode o pipeline com um passo de debug imprimindo o payload do JWT (`$ACTIONS_ID_TOKEN_REQUEST_URL`).

### 5.3 Ajustar o workflow

No `.github/workflows/terraform.yaml`, apontar para a sua role:

```yaml
- name: "Configure AWS Credentials"
  uses: aws-actions/configure-aws-credentials@v6.2.3
  with:
    role-to-assume: arn:aws:iam::<ACCOUNT_ID>:role/GithubActionsRole
    aws-region: us-east-1
```

---

## 6. Como Usar

O workflow dispara manualmente (Actions → Run workflow). O `plan` roda sempre; `apply` e `destroy` obedecem aos inputs:

| Input | Padrão | Efeito |
|---|---|---|
| `apply` | `false` | Roda `terraform apply -auto-approve` após o plan |
| `destroy` | `false` | Roda `terraform apply -destroy -auto-approve` |
| `plan_destroy` | `false` | Gera o plano de destruição (sem aplicar) |

Sequência segura para um primeiro ciclo:

1. Rodar com tudo `false`: valida o pipeline (init, validate, plan) sem custo de recursos. Veja o plano na aba de logs.
2. Rodar com `apply=true`: provisiona EC2, ECR, IAM e Security Group.
3. Ao final, rodar com `destroy=true` para remover tudo e não gerar custo.

---

## 7. Permissões da Role

Políticas anexadas à `GithubActionsRole`:

- `AmazonEC2FullAccess`: instância e Security Groups.
- `AmazonEC2ContainerRegistryFullAccess`: repositório ECR.
- `IAMFullAccess`: role `ECR-EC2-Role` e instance profile.
- `AmazonS3FullAccess`: state remoto (backend S3).

**Atenção**: a política `AmazonS3FilesFullAccess` NÃO cobre o data plane clássico do S3 (GetObject/ListBucket). Se o init falhar com `403 Forbidden` no state, use `AmazonS3FullAccess`, ou melhor, uma política escopada ao bucket do state.

Para hardening em produção, substitua `IAMFullAccess` e `AmazonS3FullAccess` por políticas escopadas (leitura de IAM e acesso apenas ao bucket `terraform-state-portfoliozzz`).

---

## 8. Custo Estimado

Dentro do Free Tier de 12 meses, o ciclo completo não gera custo (t3.micro, ECR e S3). Fora dele:

- EC2 t3.micro: aprox. US$ 7,50 por mês (24/7).
- ECR: aprox. US$ 0,10 por GB por mês (imagens pequenas).
- S3: centavos por mês para um state de poucos KB.

Rode `destroy` ao final de cada uso.

---

## 9. Limpeza de Recursos

1. Workflow com `destroy=true`, ou via CLI:

```bash
terraform init
terraform plan -destroy -out=tfplandestroy
terraform apply -destroy -auto-approve tfplandestroy
```

2. Opcional: remover a role `GithubActionsRole`, o provider OIDC e o bucket do state (só depois de destruir tudo).

---

## 10. Troubleshooting

**`Not authorized to perform sts:AssumeRoleWithWebIdentity`**
A role existe? O provider OIDC existe? O padrão do `sub` na trust policy casa com o claim real? O GitHub insere `@<id>` no sub (ex.: `repo:renatux@1243309/...@1347478107:...`). Use `repo:renatux*/*:*` e confira os claims reais com um passo de debug.

**`S3 bucket "..." does not exist` no init**
Crie o bucket do state antes do pipeline: `aws s3api create-bucket --bucket terraform-state-portfoliozzz --region us-east-1`, com versionamento habilitado.

**`403 Forbidden` ao ler o state**
A role não tem `s3:GetObject/ListBucket`. Verifique as políticas (veja a seção 7).

**`OpenIDConnect provider's HTTPS certificate doesn't match configured thumbprint`**
O thumbprint do provider está defasado (rotação de certificados do GitHub). Atualize o thumbprint em IAM → Identity providers, ou recrie o provider.

---

## 11. Referências

- [Configurar OpenID Connect na AWS (docs GitHub)](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
- [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [Documentação Terraform](https://developer.hashicorp.com/terraform/docs)

---

Licença MIT. Autor: Renato Souza.