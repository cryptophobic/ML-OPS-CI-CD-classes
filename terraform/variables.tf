variable "aws_region" {
  description = "AWS region for Lambda + Step Functions."
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Prefix applied to all created resources."
  type        = string
  default     = "mlops-train"
}

variable "lambda_runtime" {
  description = "Python runtime for both Lambda functions."
  type        = string
  default     = "python3.12"
}

variable "lambda_timeout_seconds" {
  description = "Per-invocation Lambda timeout."
  type        = number
  default     = 15
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    Project = "mlops-train-automation"
    Lesson  = "lesson-10"
  }
}