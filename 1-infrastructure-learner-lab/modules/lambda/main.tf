data "aws_caller_identity" "current" {}

resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda-sg"
  description = "Lambda security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}"
  retention_in_days = 14
}

resource "local_file" "handler" {
  filename = "${path.module}/index.py"

  content = <<PY
import json

def handler(event, context):
    print("Received event:", json.dumps(event))
    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Lambda executed successfully",
            "event": event
        })
    }
PY
}

data "archive_file" "zip" {
  type        = "zip"
  source_file = local_file.handler.filename
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "this" {

  function_name = var.project_name

  role = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"

  runtime = "python3.12"
  handler = "index.handler"

  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256

  timeout     = 30
  memory_size = 256

  reserved_concurrent_executions = 5

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  timeouts {
    delete = "10m"
  }

  environment {
    variables = {
      SECRET_ARN     = var.secret_arn
      EVENT_BUS_NAME = var.event_bus_name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda
  ]
}

resource "aws_cloudwatch_event_rule" "from_ecs" {

  name           = "${var.project_name}-from-ecs"
  event_bus_name = var.event_bus_name

  event_pattern = jsonencode({
    source      = ["app.ecs"]
    detail-type = ["task-event"]
  })
}

resource "aws_cloudwatch_event_target" "lambda" {

  rule           = aws_cloudwatch_event_rule.from_ecs.name
  event_bus_name = var.event_bus_name
  arn            = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {

  statement_id = "AllowExecutionFromEventBridge"

  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"

  source_arn = aws_cloudwatch_event_rule.from_ecs.arn
}