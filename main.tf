provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "data_bucket" {
  bucket = var.s3_bucket_name
  acl    = "private"
}

resource "aws_lambda_function" "lambda_function" {
  function_name    = var.lambda_function_name
  handler          = "main_app.main"
  runtime          = "python3.10"
  
  s3_bucket        = aws_s3_bucket.lambda_deployments.bucket
  s3_key           = aws_s3_object.lambda_zip.key

  role             = aws_iam_role.lambda_role.arn

  environment {
    variables = {
      BUCKET_NAME = var.s3_bucket_name
      FILENAME    = var.filename
    }
  }
}

resource "random_string" "suffix" {
  length           = 8
  special          = false
  override_special = "_%@"  # Exclude hyphens from the characters
  upper            = false  # Only use lowercase letters
}

resource "aws_s3_bucket" "lambda_deployments" {
  # Ensure bucket name doesn't start or end with a hyphen
  bucket = "lambda-deployment-bucket-${replace(random_string.suffix.result, "/(^[.-]|[.-]$)/", "")}"
}

resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.lambda_deployments.bucket
  key    = var.package_file_zip
  source = var.package_file_zip
  etag   = filemd5(var.package_file_zip)
}

resource "aws_iam_role" "lambda_role" {
  name = "role_${var.lambda_function_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_s3_access" {
  name = "policy_${var.lambda_function_name}_s3_access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["s3:PutObject"],
        Resource = ["${aws_s3_bucket.data_bucket.arn}/*"],
        Effect   = "Allow"
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "daily_schedule" {
  name                = "rule_${var.lambda_function_name}_daily"
  schedule_expression = "cron(0 12 * * ? *)" # This runs daily at 12:00pm UTC.
}

resource "aws_cloudwatch_event_target" "invoke_lambda_daily" {
  rule      = aws_cloudwatch_event_rule.daily_schedule.name
  target_id = var.lambda_function_name
  arn       = aws_lambda_function.lambda_function.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_schedule.arn
}
