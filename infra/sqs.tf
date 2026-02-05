resource "aws_sqs_queue" "dlq" {
  name                      = "${local.name_prefix}-activities-dlq"
  message_retention_seconds = 1209600
  tags                      = local.tags
}

resource "aws_sqs_queue" "activities_q" {
  name                       = "${local.name_prefix}-activities-q"
  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds
  message_retention_seconds  = 345600

  redrive_policy = jsonencode(
    {
      deadLetterTargetArn = aws_sqs_queue.dlq.arn
      maxReceiveCount     = 5
    }
  )

  tags = local.tags
}
