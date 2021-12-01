# Defining IAM policy for ECS role (permissions for ECS Tasks
data "aws_iam_policy_document" "ecs_role_policy" {
  statement {
    sid    = "AllowUseOfTheKey"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = [module.kms_secret_manager.ARN_KMS]
  }
  statement {
    sid    = "AllowECRActions"
    effect = "Allow"
    actions = [
      "ECR:Decrypt",
      "kms:DescribeKey"
    ]
    resources = [module.kms_secret_manager.ARN_KMS]
  }
  statement {
    sid    = "AllowS3Actions"
    effect = "Allow"
    actions = [
      "s3:get*",
      "s3:put*"
    ]
    resources = [module.s3-content.s3_bucket_arn]
  }

}

###  KMS Policy 
data "aws_iam_policy_document" "kms_policy" {
  statement {
    sid    = "AllowUseOfTheKey"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [module.ecs_role.ARN_ROLE]
    }
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = ["*"]
  }
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.ID_CURRENT_ACCOUNT.account_id}:root"]
    }
    actions = [
      "*"
    ]
    resources = ["*"]

  }
}


### Secret Manager Policy
data "aws_iam_policy_document" "secret_manager_policy" {
  statement {
    sid    = "AllowUseSecrerManager"
    effect = "Allow"
    actions = [
      "secretsmanager:*"
    ]
    principals {
      type        = "AWS"
      identifiers = [module.ecs_role.ARN_ROLE]
    }
    resources = ["*"]
  }
}

### Secret Manager Policy
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid    = "AllowUseSecrerManager"
    effect = "Allow"
    actions = [
      "secretsmanager:*"
    ]
    resources = [module.secret_manager.SECRET_ARN]
  }
  statement {
    sid    = "AllowKMS"
    effect = "Allow"
    actions = [
      "KMS:*"
    ]
    resources = [module.kms_secret_manager.ARN_KMS]
  }
    statement {
    sid    = "Allowlogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

