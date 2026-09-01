#--------------------------------
# Application Access IAM Policy
#--------------------------------

resource "aws_iam_policy" "distribution_app_access" {
  name        = "distribution-app-access"
  description = "Least-privilege access for the distribution application"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ListDistributionBucket"
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = [
          aws_s3_bucket.distribution_bucket.arn
        ]
      },
      {
        Sid    = "AccessDistributionObjects"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]

        Resource = [
          "${aws_s3_bucket.distribution_bucket.arn}/*"
        ]
      },
      {
        Sid    = "ReadDatabaseSecret"
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue"
        ]

        Resource = [
          aws_db_instance.distribution_mysql.master_user_secret[0].secret_arn
        ]
      }
    ]
  })

  tags = {
    Name        = "distribution-app-access"
    environment = "development"
    managed_by  = "Terraform"
  }
}

#--------------------------------
# Attach Policy to EC2 Role
#--------------------------------

resource "aws_iam_role_policy_attachment" "distribution_app_access" {
  role       = aws_iam_role.distribution_ec2_role.name
  policy_arn = aws_iam_policy.distribution_app_access.arn
}