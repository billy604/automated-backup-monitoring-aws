resource "aws_sns_topic" "alerts" {
  name = "backup-monitoring-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "billyjoesilagan@gmail.com"
}