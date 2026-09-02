# 🚀 Portfolio DevOps: Pipeline Multi-ambiente com Terraform, OIDC e deploy via SSM

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?logo=githubactions&logoColor=white)](https://github.com/features/actions)
[![Terraform](https://img.shields.io/badge/Terraform-844FBA?logo=terraform&logoColor=white)](https://www.terraform.io)
[![OIDC](https://img.shields.io/badge/OIDC-0B6E4F?logo=openid&logoColor=white)](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
[![Amazon AWS](https://img.shields.io/badge/AWS-FF9900?logo=amazonaws&logoColor=white)](https://aws.amazon.com)

Pipeline de CI/CD que provisiona infraestrutura AWS com Terraform e publica a aplicação em **três ambientes isolados (dev, staging, prod)** sem nenhuma access key estática: a autenticação é via OpenID Connect (OIDC), o deploy na instância é via **SSM Run Command (sem porta 22 aberta)**, e cada ambiente tem o próprio estado Terraform.

## Índice

1. [Arquitetura](#1-arquitetura)
2. [Ambientes e fluxo de promoção](#2-ambientes-e-fluxo-de-promoção)
3. [Estrutura do Repositório](#3-estrutura-do-repositório)
4. [Pré-requisitos](#4-pré-requisitos)
5. [Configuração do OIDC na AWS](#5-configuração-do-oidc-na-aws)
6. [Como Usar](#6-como-usar)
7. [Permissões e Segurança](#7-permissões-e-segurança)
8. [Custo Estimado](#8-custo-estimado)
9. [Troubleshooting](#9-troubleshooting)
10. [Decisões Técnicas](#10-decisões-técnicas)

---

## 1. Arquitetura

```
+----------------------+        +----------------------------+        +--------------------------+
| GitHub Actions       |        | AWS STS                    |        | Terraform (no runner)    |
| push em branch/tag   | -----> | sts:AssumeRoleWithWebIdentity| ----> | init -> validate -> plan |
+----------------------+   JWT  +----------------------------+        | apply / destroy (inputs) |
        |                        |  roles: GithubActionsRole         +--------------------------+
        |                        |         GithubActionsRepoApp                 |
        |                        v                                          v
        |               +----------------------------+            +--------------------------+
        +-------------> | OIDC Provider               |            | AWS por ambiente          |
                        | token.actions.githubusercontent.com     | EC2 t3.micro + SG + role  |
                        | + trust policy por repo      |            | ECR webportfolio (sha)    |
                        +----------------------------+            | State remoto por ambiente |
                                                                  +--------------------------+
        Deploy da imagem: push -> build -> ECR -> SSM Run Command -> docker run na EC2
```

Fluxo resumido: o GitHub emite um JWT assinado (com `sub` e `aud`), a AWS valida contra o provider OIDC e a trust policy da role, entrega credenciais temporárias, o Terraform opera os recursos, e a imagem do site é entregue na instância por SSM, sem SSH e sem chave no servidor.

## 2. Ambientes e fluxo de promoção

| Ambiente | Gatilho | Imagem no ECR | Instância (tag `Name`) |
|---|---|---|---|
| `dev` | push na branch `develop` | `webportfolio:dev-<sha>` | `website-server-dev` |
| `staging` | push na branch `main` | `webportfolio:staging-<sha>` | `website-server-staging` |
| `prod` | tag `v*` (ex.: `v1.0.0`) + aprovação | `webportfolio:prod-<sha>` | `website-server-prod` |

A imagem é sempre tag imutável por commit (`<ambiente>-<sha8>`), então o que foi homologado em staging é exatamente o que promove para prod, e o rollback é re-executar o deploy de um sha anterior.

## 3. Estrutura do Repositório

```
portfolio-devops-fase-cicd/
├── .github/workflows/
│   ├── deploy.yaml            # Deploy por ref: dev/staging/prod (3 jobs, if por ref)
│   ├── terraform.yaml         # Provisiona Ambiente Portfolio (apply/destroy com inputs)
│   └── destroy.yaml           # Destroi UM ambiente (confirmação DESTRUIR)
├── infra/
│   ├── core/                  # Recursos COMPARTILHADOS (ECR webportfolio), uma única vez
│   ├── modules/ec2/           # Módulo único parametrizado (EC2, SG, role, user_data, outputs)
│   ├── common.tfvars          # Valores comuns aos 3 ambientes (vpc_id)
│   ├── dev/  staging/  prod/  # Raízes por ambiente: backend.tf + main.tf + <env>.tfvars
│   └── provider.tf
└── website/                   # Site estático servido pelo container (nginx)
```

Cada raiz de ambiente tem o próprio `backend "s3"` com key própria (`portfoliozzz/<ambiente>/terraform.tfstate`), isolando o estado e o blast radius: um erro em dev não alcança prod.

## 4. Pré-requisitos

- Conta AWS com credenciais de administrador para a configuração inicial (bootstrap OIDC).
- Bucket S3 do state (`terraform-state-portfoliozzz`) com versionamento e criptografia.
- Environments no GitHub: `dev`, `staging` e `prod` (Settings → Environments; em `prod`, ativar Required reviewers para a porta de produção).

## 5. Configuração do OIDC na AWS

O provider OIDC aponta para `token.actions.githubusercontent.com` com Client ID `sts.amazonaws.com`. A trust policy da role de pipeline usa o claim `sub` no formato atual do GitHub, com IDs numéricos:

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
          "token.actions.githubusercontent.com:sub": "repo:renatux@<USER_ID>/*@<REPO_ID>:*"
        }
      }
    }
  ]
}
```

**Atenção ao formato do `sub`**: o GitHub insere IDs numéricos no claim (`repo:renatux@<user_id>/<repo>@<repo_id>:ref:refs/heads/main`). O padrão clássico `repo:owner/repo:*` não casa e derruba o pipeline com `Not authorized to perform sts:AssumeRoleWithWebIdentity`. Manter os IDs com o curinga no nome do repositório (`*@<repo_id>:*`) torna a trust resistente a renomeações.

## 6. Como Usar

### Provisionar um ambiente (criar a infraestrutura)

Actions → **Provisiona Ambiente Portfolio** → inputs: `ambiente` (dev/staging/prod), `apply=true` (o plan roda sempre, o apply só com o input).

```bash
gh workflow run 343025104 -f ambiente=dev -f apply=true
```

O primeiro apply do `infra/core` precisa do import do ECR que já existe na conta (documentado no próprio `main.tf`):

```bash
cd infra/core
terraform init -input=false
terraform import aws_ecr_repository.ecr_portfolio webportfolio
terraform apply -auto-approve
```

### Publicar (deploy)

```bash
git push origin develop        # publica em dev
git push origin main           # publica em staging
git tag v1.0.0 && git push origin v1.0.0   # publica em prod (após aprovação)
```

A instância deve existir: o pipeline entrega a imagem, quem provisiona é o Terraform. Uma instância nova leva 1 a 3 minutos para o agente SSM registrar.

### Destruir um ambiente

Actions → **Destruir Ambiente Portfolio** → `ambiente` + digitar `DESTRUIR`. O workflow gera o plano de destruição, aplica e só termina verde com o state vazio. O ECR compartilhado não é tocado (vive no `core/`).

## 7. Permissões e Segurança

| Role | Função | Escopo |
|---|---|---|
| `GithubActionsRepoApp` | Pipeline de deploy (build/push ECR + SSM) | Inline com menor privilégio: push ECR restrito ao `webportfolio`, `ssm:SendCommand` no documento, na instância por tag (`website-server-*`) e no managed-instance |
| `GithubActionsRole` | Terraform (provisionar/destruir) | EC2, IAM, ECR e S3 do state |
| `ECR-EC2-Role-<env>` | Runtime da instância | `AmazonSSMManagedInstanceCore` + pull ECR escopado ao repositório |

Camadas de segurança: zero access keys estáticas (OIDC com token de curta duração), deploy sem porta 22 (SSM auditável no CloudTrail), SG com SSH apenas do IP de manutenção, escalation de destruição com confirmação por digitação e `environment: prod` com required reviewers.

## 8. Custo Estimado

- EC2 t3.micro por ambiente: ~US$ 8,50/mês cada (dev, staging e prod). Política de lab: subir sob demanda e destruir quando não usar via `destroy.yaml`.
- ECR: ~US$ 0,10/GB/mês (imagens pequenas).
- S3 (state): centavos por mês.

## 9. Troubleshooting

**`Not authorized to perform sts:AssumeRoleWithWebIdentity`**
O claim `sub` não casa com a trust policy. Conferir o formato com IDs (`@<user_id>` e `@<repo_id>`) e usar o padrão com curinga.

**`Instancia alvo: None` → ValidationException no SendCommand**
Não existe instância com a tag esperada em estado running. O guard do pipeline imprime a orientação: rodar o apply do ambiente antes do deploy. O deploy entrega, o Terraform provisiona.

**`AccessDeniedException` no `ssm:SendCommand`**
A role não tem permissão em um dos três recursos exigidos: documento (`arn:aws:ssm:...::document/...`, sem conta), instância EC2 (com condição de tag) e managed-instance (`arn:aws:ssm:<reg>:<acct>:managed-instance/*`). Os três precisam existir na policy.

**`RepositoryAlreadyExistsException` no apply**
O ECR `webportfolio` já existe na conta e está fora do state de um ambiente. Tratar via `infra/core` com import, nunca remover o repositório.

**`--var-file` sem o `common.tfvars`**
Valores comuns (ex.: `vpc_id`) vivem em `infra/common.tfvars`; os workflows passam `-var-file=../common.tfvars -var-file=<env>.tfvars` (nesta ordem, o específico vence).

## 10. Decisões Técnicas

- **Um código, três raízes.** O módulo `modules/ec2` carrega o conhecimento; cada raiz de ambiente carrega a identidade (backend + tfvars); o versionamento futuro do módulo carrega a história. Nada de cópia de infra por ambiente.
- **State por ambiente.** Estados separados isolam o erro e permitem destruir um ambiente sem tocar os outros.
- **ECR compartilhado no `core/`.** A imagem se distingue pela tag, não pelo repositório; o ECR é provisionado uma vez, fora do ciclo de ambiente.
- **Tag imutável por sha.** O resultado do deploy é determinístico e o rollback é um sha de distância.
- **SSM em vez de SSH.** Sem chave no servidor, sem porta exposta, execução registrada no CloudTrail.
- **Guard no deploy.** O pipeline fala a língua do operador: se a instância não existe, ele diz qual apply rodar, em vez de devolver uma validação criptografada da API.

**Limitações honestas:** preço de mercado é um campo fixo no ativo (feed real seria a evolução); sem paginação nas listagens da API; AMI do EC2 fixa no módulo (evolução: `data "aws_ami"`); multi-conta por ambiente é o próximo nível de isolamento em empresas.

---

Licença MIT. Autor: Renato Souza.