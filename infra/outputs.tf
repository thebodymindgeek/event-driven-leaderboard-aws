output "activities_table" { value = aws_dynamodb_table.activities.name }
output "program_progress_table" { value = aws_dynamodb_table.program_progress.name }
output "employee_totals_table" { value = aws_dynamodb_table.employee_totals.name }
output "global_leaderboard_table" { value = aws_dynamodb_table.global_leaderboard.name }

output "activities_queue_url" { value = aws_sqs_queue.activities_q.url }
output "dlq_url" { value = aws_sqs_queue.dlq.url }

output "sns_topic_arn" { value = aws_sns_topic.notif.arn }

output "dashboard_bucket_website" {
  value = aws_s3_bucket_website_configuration.dashboard.website_endpoint
}

output "pipe_name" { value = aws_pipes_pipe.ddb_stream_to_sqs.name }
