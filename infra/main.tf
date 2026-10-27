terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  service_name = "refund-settlement"
  lambda_zip   = "${path.module}/../build/refund_worker.zip"
  common_tags = {
    Service     = "refund-settlement"
    Environment = "sandbox"
    Owner       = "marketplace-payments"
  }
}

resource "aws_s3_bucket" "settlements" {
  bucket        = "refund-settlements-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = local.common_tags
}

resource "aws_dynamodb_table" "ledger" {
  name         = "refund-settlement-ledger"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "settlement_id"

  attribute {
    name = "settlement_id"
    type = "S"
  }

  tags = local.common_tags
}

resource "aws_sqs_queue" "refund_dlq" {
  name                      = "refund-settlement-dlq"
  message_retention_seconds = 1209600
  tags                      = local.common_tags
}

resource "aws_sqs_queue" "refund_requests" {
  name                       = "refund-settlement-requests"
  visibility_timeout_seconds = 10
  message_retention_seconds  = 1209600
  receive_wait_time_seconds  = 1
  tags                       = local.common_tags
}

resource "aws_iam_role" "lambda_role" {
  name = "refund-settlement-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "refund-settlement-worker-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = aws_sqs_queue.refund_requests.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.settlements.arn,
          "${aws_s3_bucket.settlements.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.ledger.arn
      }
    ]
  })
}

resource "aws_lambda_function" "worker" {
  function_name    = "refund-settlement-worker"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  filename         = local.lambda_zip
  source_code_hash = filebase64sha256(local.lambda_zip)
  timeout          = 10
  memory_size      = 256

  environment {
    variables = {
      SETTLEMENT_BUCKET = aws_s3_bucket.settlements.bucket
      LEDGER_TABLE      = aws_dynamodb_table.ledger.name
      LOG_LEVEL         = "INFO"
    }
  }

  tags = local.common_tags
}

resource "aws_lambda_event_source_mapping" "refund_queue" {
  event_source_arn = aws_sqs_queue.refund_requests.arn
  function_name    = aws_lambda_function.worker.arn
  enabled          = true
  batch_size       = 5
}
