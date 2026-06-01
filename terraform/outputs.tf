output "state_machine_arn" {
  description = "ARN of the Step Functions state machine — paste into .gitlab-ci.yml as STATE_MACHINE_ARN."
  value       = aws_sfn_state_machine.train.arn
}

output "state_machine_name" {
  description = "Name of the Step Functions state machine."
  value       = aws_sfn_state_machine.train.name
}

output "validate_lambda_name" {
  value = aws_lambda_function.validate.function_name
}

output "log_metrics_lambda_name" {
  value = aws_lambda_function.log_metrics.function_name
}

output "manual_start_command" {
  description = "Copy-paste to trigger a run from your laptop."
  value       = "aws stepfunctions start-execution --region ${var.aws_region} --state-machine-arn ${aws_sfn_state_machine.train.arn} --name manual-$(date +%s) --input '{\"source\":\"manual\",\"commit\":\"local-test\",\"rows\":1500}'"
}