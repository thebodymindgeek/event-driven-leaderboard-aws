resource "aws_cloudwatch_log_group" "processor" {
  name              = "/aws/lambda/${aws_lambda_function.activity_processor.function_name}"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "rebuilder" {
  name              = "/aws/lambda/${aws_lambda_function.leaderboard_rebuilder.function_name}"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "simulator" {
  name              = "/aws/lambda/${aws_lambda_function.activity_simulator.function_name}"
  retention_in_days = 7
  tags              = local.tags
}

resource "aws_cloudwatch_metric_alarm" "processor_errors" {
  alarm_name          = "${local.name_prefix}-activity-processor-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0

  dimensions = {
    FunctionName = aws_lambda_function.activity_processor.function_name
  }

  alarm_actions = [aws_sns_topic.notif.arn]
  ok_actions    = [aws_sns_topic.notif.arn]
  tags          = local.tags
}

resource "aws_cloudwatch_metric_alarm" "rebuilder_errors" {
  alarm_name          = "${local.name_prefix}-leaderboard-rebuilder-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0

  dimensions = {
    FunctionName = aws_lambda_function.leaderboard_rebuilder.function_name
  }

  alarm_actions = [aws_sns_topic.notif.arn]
  ok_actions    = [aws_sns_topic.notif.arn]
  tags          = local.tags
}

resource "aws_cloudwatch_metric_alarm" "sqs_age" {
  alarm_name          = "${local.name_prefix}-sqs-age-oldest"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = var.sqs_age_oldest_seconds_threshold

  dimensions = {
    QueueName = aws_sqs_queue.activities_q.name
  }

  alarm_actions = [aws_sns_topic.notif.arn]
  ok_actions    = [aws_sns_topic.notif.arn]
  tags          = local.tags
}

resource "aws_cloudwatch_metric_alarm" "dlq_received" {
  alarm_name          = "${local.name_prefix}-dlq-messages-received"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "NumberOfMessagesReceived"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 1

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  alarm_actions = [aws_sns_topic.notif.arn]
  ok_actions    = [aws_sns_topic.notif.arn]
  tags          = local.tags
}
resource "aws_cloudwatch_dashboard" "edl" {
  dashboard_name = "${local.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          region = var.aws_region
          annotations = {
            horizontal = []
            vertical   = []
          }

          title  = "Lambda Invocations & Errors"
          period = 60
          stat   = "Sum"

          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.activity_processor.function_name],
            [".", "Errors", ".", aws_lambda_function.activity_processor.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.leaderboard_rebuilder.function_name],
            [".", "Errors", ".", aws_lambda_function.leaderboard_rebuilder.function_name]
          ]
        }
      }
      # keep your other widgets below...
    ]
  })
}


# ---------- Alarm: SQS backlog (stuck pipeline) ----------
resource "aws_cloudwatch_metric_alarm" "sqs_oldest_message" {
  alarm_name          = "${local.name_prefix}-sqs-age-oldest"
  alarm_description   = "Pipeline stuck: AgeOfOldestMessage above threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = var.sqs_age_oldest_seconds_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.activities_q.name
  }

  alarm_actions = [aws_sns_topic.notif.arn]
  ok_actions    = [aws_sns_topic.notif.arn]

  tags = local.tags
}

# ---------- Alarm: DLQ has messages  ----------
resource "aws_cloudwatch_metric_alarm" "dlq_messages_visible" {
  alarm_name          = "${local.name_prefix}-dlq-visible"
  alarm_description   = "DLQ has messages. Investigate failed events."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  alarm_actions = [aws_sns_topic.notif.arn]
  ok_actions    = [aws_sns_topic.notif.arn]

  tags = local.tags
}