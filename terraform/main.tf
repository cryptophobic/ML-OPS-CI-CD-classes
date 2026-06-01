# Lesson-10 automation infra:
#   ValidateData (Lambda) → LogMetrics (Lambda) — orchestrated by Step Functions.
#
# Layout:
#   - aws_iam_role.lambda_exec        — assume by lambda.amazonaws.com; CW logs
#   - aws_lambda_function.validate    — terraform/lambda/validate.zip
#   - aws_lambda_function.log_metrics — terraform/lambda/log_metrics.zip
#   - aws_iam_role.step_fn_exec       — assume by states.amazonaws.com
#   - aws_sfn_state_machine.train     — ASL describing the two-step flow
#   - aws_cloudwatch_log_group        — explicit retention for each Lambda

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = var.tags
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = var.project_name
}

# ----------------------------------------------------------------------------
# Re-pack the python sources at apply time so that the committed .zip files
# stay in sync with the .py sources. Output paths overwrite the static
# terraform/lambda/<name>.zip artifacts referenced by the task description.
# ----------------------------------------------------------------------------
data "archive_file" "validate" {
  type        = "zip"
  source_file = "${path.module}/lambda/validate.py"
  output_path = "${path.module}/lambda/validate.zip"
}

data "archive_file" "log_metrics" {
  type        = "zip"
  source_file = "${path.module}/lambda/log_metrics.py"
  output_path = "${path.module}/lambda/log_metrics.zip"
}

# ----------------------------------------------------------------------------
# IAM — Lambda execution role + CloudWatch logs access
# ----------------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${local.name_prefix}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ----------------------------------------------------------------------------
# Lambda log groups with explicit retention (would otherwise default to "never")
# ----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "validate" {
  name              = "/aws/lambda/${local.name_prefix}-validate"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "log_metrics" {
  name              = "/aws/lambda/${local.name_prefix}-log-metrics"
  retention_in_days = 7
}

# ----------------------------------------------------------------------------
# Lambda functions
# ----------------------------------------------------------------------------
resource "aws_lambda_function" "validate" {
  function_name    = "${local.name_prefix}-validate"
  role             = aws_iam_role.lambda_exec.arn
  filename         = data.archive_file.validate.output_path
  source_code_hash = data.archive_file.validate.output_base64sha256
  handler          = "validate.lambda_handler"
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout_seconds

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.validate,
  ]
}

resource "aws_lambda_function" "log_metrics" {
  function_name    = "${local.name_prefix}-log-metrics"
  role             = aws_iam_role.lambda_exec.arn
  filename         = data.archive_file.log_metrics.output_path
  source_code_hash = data.archive_file.log_metrics.output_base64sha256
  handler          = "log_metrics.lambda_handler"
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout_seconds

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.log_metrics,
  ]
}

# ----------------------------------------------------------------------------
# Step Functions — execution role + state machine
# ----------------------------------------------------------------------------
data "aws_iam_policy_document" "step_fn_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "step_fn_invoke_lambda" {
  statement {
    actions = ["lambda:InvokeFunction"]
    resources = [
      aws_lambda_function.validate.arn,
      aws_lambda_function.log_metrics.arn,
      "${aws_lambda_function.validate.arn}:*",
      "${aws_lambda_function.log_metrics.arn}:*",
    ]
  }

  statement {
    actions   = ["logs:CreateLogDelivery", "logs:GetLogDelivery", "logs:UpdateLogDelivery", "logs:DeleteLogDelivery", "logs:ListLogDeliveries", "logs:PutResourcePolicy", "logs:DescribeResourcePolicies", "logs:DescribeLogGroups"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "step_fn_exec" {
  name               = "${local.name_prefix}-step-fn-exec"
  assume_role_policy = data.aws_iam_policy_document.step_fn_assume.json
}

resource "aws_iam_role_policy" "step_fn_invoke" {
  name   = "${local.name_prefix}-step-fn-invoke"
  role   = aws_iam_role.step_fn_exec.id
  policy = data.aws_iam_policy_document.step_fn_invoke_lambda.json
}

resource "aws_cloudwatch_log_group" "step_fn" {
  name              = "/aws/vendedlogs/states/${local.name_prefix}-train"
  retention_in_days = 7
}

resource "aws_sfn_state_machine" "train" {
  name     = "${local.name_prefix}-train"
  role_arn = aws_iam_role.step_fn_exec.arn

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_fn.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  definition = jsonencode({
    Comment = "Train pipeline: ValidateData → LogMetrics"
    StartAt = "ValidateData"
    States = {
      ValidateData = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.validate.arn
          "Payload.$"  = "$"
        }
        ResultSelector = {
          "validated.$" = "$.Payload"
        }
        ResultPath = "$.previous"
        Retry = [{
          ErrorEquals     = ["States.TaskFailed"]
          IntervalSeconds = 2
          MaxAttempts     = 2
          BackoffRate     = 2.0
        }]
        Next = "LogMetrics"
      }
      LogMetrics = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.log_metrics.arn
          "Payload.$"  = "$.previous.validated"
        }
        ResultSelector = {
          "metrics.$" = "$.Payload"
        }
        ResultPath = "$.previous"
        End        = true
      }
    }
  })

  depends_on = [aws_iam_role_policy.step_fn_invoke]
}