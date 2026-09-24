data "aws_db_instance" "three_tier_db" {
  db_instance_identifier = "three-tier-db"
}

data "aws_autoscaling_group" "three_tier_asg" {
  name = "app-tier-asg"
}

resource "aws_cloudwatch_metric_alarm" "rds_high_connections" {
  alarm_name          = "rds-high-connection-count"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 2
  metric_name          = "DatabaseConnections"
  namespace            = "AWS/RDS"
  period               = 300
  statistic            = "Average"
  threshold            = 50

  dimensions = {
    DBInstanceIdentifier = data.aws_db_instance.three_tier_db.db_instance_identifier
  }

  alarm_description = "Triggers if the RDS database has an unusually high number of open connections"
  alarm_actions      = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "asg_high_cpu" {
  alarm_name          = "app-tier-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 2
  metric_name          = "CPUUtilization"
  namespace            = "AWS/EC2"
  period               = 300
  statistic            = "Average"
  threshold            = 80

  dimensions = {
    AutoScalingGroupName = data.aws_autoscaling_group.three_tier_asg.name
  }

  alarm_description = "Triggers if average CPU across the app tier stays above 80% for 10 minutes"
  alarm_actions      = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "backup_errors" {
  alarm_name          = "backup-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 1
  metric_name          = "Errors"
  namespace            = "AWS/Lambda"
  period               = 300
  statistic            = "Sum"
  threshold            = 0

  dimensions = {
    FunctionName = aws_lambda_function.backup.function_name
  }

  alarm_description = "Triggers if the backup Lambda has any execution errors"
  alarm_actions      = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "cleanup_errors" {
  alarm_name          = "cleanup-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 1
  metric_name          = "Errors"
  namespace            = "AWS/Lambda"
  period               = 300
  statistic            = "Sum"
  threshold            = 0

  dimensions = {
    FunctionName = aws_lambda_function.cleanup.function_name
  }

  alarm_description = "Triggers if the cleanup Lambda has any execution errors"
  alarm_actions      = [aws_sns_topic.alerts.arn]
}