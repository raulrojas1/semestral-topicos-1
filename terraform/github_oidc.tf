# Acceso de GitHub Actions a AWS por OIDC: sin claves de acceso almacenadas.

resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_github_oidc_provider ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

locals {
  oidc_provider_arn = (
    var.create_github_oidc_provider
    ? aws_iam_openid_connect_provider.github[0].arn
    : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
  )
}

# GitHub emite el claim "sub" en dos formatos segun el repositorio:
#   clasico:             repo:owner/repo:ref:refs/heads/main
#   con IDs inmutables:  repo:owner@<id>/repo@<id>:ref:refs/heads/main
# Se aceptan ambos. En el segundo solo se comodinan los IDs: el nombre del dueno y del repo
# siguen fijos, asi que ningun otro usuario u organizacion puede asumir los roles.
locals {
  oidc_owner = split("/", var.github_repository)[0]
  oidc_repo  = split("/", var.github_repository)[1]
}

# Solo workflows del repo indicado, en la rama indicada, pueden asumir los roles.
data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repository}:ref:refs/heads/${var.github_branch}",
        "repo:${var.github_repository}:pull_request",
        "repo:${local.oidc_owner}@*/${local.oidc_repo}@*:ref:refs/heads/${var.github_branch}",
        "repo:${local.oidc_owner}@*/${local.oidc_repo}@*:pull_request",
      ]
    }
  }
}

# --- Rol para pipelines 2 y 3 (mínimo privilegio) ---
resource "aws_iam_role" "github_app" {
  name               = "${var.project_name}-github-app"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}

data "aws_iam_policy_document" "github_app" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPushPull"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [for r in aws_ecr_repository.app : r.arn]
  }

  statement {
    sid = "EcsDeploy"
    actions = [
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "PassTaskRoles"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.task_execution.arn, aws_iam_role.task.arn]
  }

  statement {
    sid       = "ReadAlb"
    actions   = ["elasticloadbalancing:DescribeLoadBalancers"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_app" {
  name   = "app-pipelines"
  role   = aws_iam_role.github_app.id
  policy = data.aws_iam_policy_document.github_app.json
}

# --- Rol para pipeline 1 (Terraform) ---
# AdministratorAccess por simplicidad en un proyecto académico. En producción, acotar a los
# servicios que gestiona este código.
resource "aws_iam_role" "github_terraform" {
  name               = "${var.project_name}-github-terraform"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}

resource "aws_iam_role_policy_attachment" "github_terraform" {
  role       = aws_iam_role.github_terraform.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
