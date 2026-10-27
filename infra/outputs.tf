output "refund_queue_url" {
  value = aws_sqs_queue.refund_requests.url
}

output "refund_queue_arn" {
  value = aws_sqs_queue.refund_requests.arn
}

output "refund_dlq_url" {
  value = aws_sqs_queue.refund_dlq.url
}

output "settlement_bucket" {
  value = aws_s3_bucket.settlements.bucket
}

output "ledger_table" {
  value = aws_dynamodb_table.ledger.name
}

output "lambda_function_name" {
  value = aws_lambda_function.worker.function_name
}
