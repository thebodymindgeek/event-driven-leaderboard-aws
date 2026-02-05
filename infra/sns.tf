resource "aws_sns_topic" "notif" {
  name = "${local.name_prefix}-notif"
  tags = local.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.notif.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
