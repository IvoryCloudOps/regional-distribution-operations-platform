#--------------------------------
# GitHub Actions OIDC Provider
#--------------------------------

resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name        = "github-actions-oidc"
    environment = "development"
    managed_by  = "Terraform"
  }
}

#--------------------------------
# IAM Role for GitHub Actions
#--------------------------------

resource "aws_iam_role" "github_actions_oidc_role" {
  name = "github-actions-oidc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:IvoryCloudOps/regional-distribution-operations-platform:*"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "github-actions-oidc-role"
    environment = "development"
    managed_by  = "Terraform"
  }
}

#--------------------------------
# Terraform State Backend Policy
#--------------------------------

resource "aws_iam_policy" "github_actions_state_access" {
  name        = "github-actions-tfstate-access"
  description = "Allows GitHub Actions OIDC role to access S3 remote state and lockfile"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TFStateBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketVersioning"
        ]
        Resource = [
          "arn:aws:s3:::ivorycloudops-distribution-tfstate"
        ]
      },
      {
        Sid    = "TFStateObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::ivorycloudops-distribution-tfstate/*"
        ]
      }
    ]
  })

  tags = {
    Name        = "github-actions-tfstate-access"
    environment = "development"
    managed_by  = "Terraform"
  }
}

#--------------------------------
# Policy Attachments
#--------------------------------

# 1. State bucket access for init / lockfile / plan
resource "aws_iam_role_policy_attachment" "github_actions_state_access" {
  role       = aws_iam_role.github_actions_oidc_role.name
  policy_arn = aws_iam_policy.github_actions_state_access.arn
}

# 2. AWS read-only inspection access for terraform plan
resource "aws_iam_role_policy_attachment" "github_actions_readonly" {
  role       = aws_iam_role.github_actions_oidc_role.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}