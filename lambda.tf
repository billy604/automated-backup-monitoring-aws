data "archive_file" "backup_zip" {
  type        = "zip"
  source_file = "lambda/backup_handler.py"
  output_path = "lambda/backup_handler.zip"
}

data "archive_file" "cleanup_zip" {
  type        = "zip"
  source_file = "lambda/cleanup_handler.py"
  output_path = "lambda/cleanup_handler.zip"
}

resource "aws_lambda_function" "backup" {
  function_name = "automated-ebs-backup"
  role          = aws_iam_role.lambda_backup_role.arn
  handler       = "backup_handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60

  filename         = data.archive_file.backup_zip.output_path
  source_code_hash = data.archive_file.backup_zip.output_base64sha256
}

resource "aws_lambda_function" "cleanup" {
  function_name = "automated-ebs-cleanup"
  role          = aws_iam_role.lambda_backup_role.arn
  handler       = "cleanup_handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60

  filename         = data.archive_file.cleanup_zip.output_path
  source_code_hash = data.archive_file.cleanup_zip.output_base64sha256

  environment {
    variables = {
      RETENTION_DAYS = "7"
    }
  }
}