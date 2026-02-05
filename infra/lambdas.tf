data "archive_file" "activity_processor_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/activity_processor"
  output_path = "${path.module}/../dist/activity_processor.zip"
}

data "archive_file" "leaderboard_rebuilder_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/leaderboard_rebuilder"
  output_path = "${path.module}/../dist/leaderboard_rebuilder.zip"
}

data "archive_file" "activity_simulator_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/activity_simulator"
  output_path = "${path.module}/../dist/activity_simulator.zip"
}

data "archive_file" "getleaderboard_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/getleaderboard"
  output_path = "${path.module}/../dist/getleaderboard.zip"
}
resource "aws_lambda_function" "activity_processor" {
  function_name = "${local.name_prefix}-activity-processor"
  role          = aws_iam_role.activity_processor.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.14"

filename         = data.archive_file.activity_processor_zip.output_path
source_code_hash = data.archive_file.activity_processor_zip.output_base64sha256


  timeout     = var.processor_timeout_seconds
  memory_size = var.processor_memory_mb

  environment {
    variables = {
      NOTIF_TOPIC_ARN        = aws_sns_topic.notif.arn
      PROCESSED_EVENTS_TABLE = aws_dynamodb_table.processed_events.name
      PROGRAM_PROGRESS_TABLE = aws_dynamodb_table.program_progress.name
      EMPLOYEE_TOTALS_TABLE  = aws_dynamodb_table.employee_totals.name
      DEDUP_TTL_DAYS         = "14"
    }
  }

  tags = local.tags
}

resource "aws_lambda_event_source_mapping" "processor_from_sqs" {
  event_source_arn = aws_sqs_queue.activities_q.arn
  function_name    = aws_lambda_function.activity_processor.arn

  batch_size                         = 1
  maximum_batching_window_in_seconds = 0
  enabled                            = true
}

resource "aws_lambda_function" "leaderboard_rebuilder" {
  function_name = "${local.name_prefix}-leaderboard-rebuilder"
  role          = aws_iam_role.rebuilder.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.14"
  
  filename         = data.archive_file.leaderboard_rebuilder_zip.output_path
  source_code_hash = data.archive_file.leaderboard_rebuilder_zip.output_base64sha256


  timeout     = 60
  memory_size = 256

  environment {
    variables = {
      EMPLOYEE_TOTALS_TABLE    = aws_dynamodb_table.employee_totals.name
      EMPLOYEE_TOTALS_GSI      = "GSI_Leaderboard"
      GLOBAL_LEADERBOARD_TABLE = aws_dynamodb_table.global_leaderboard.name
      LEADERBOARD_ID           = "GLOBAL"
      TOP_N                    = "20"
    }
  }

  tags = local.tags
}

resource "aws_lambda_function" "activity_simulator" {
  function_name = "${local.name_prefix}-activity-simulator"
  role          = aws_iam_role.simulator.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.14"

filename         = data.archive_file.activity_simulator_zip.output_path
source_code_hash = data.archive_file.activity_simulator_zip.output_base64sha256

  timeout     = 15
  memory_size = 128

  environment {
    variables = {
      ACTIVITIES_TABLE = aws_dynamodb_table.activities.name
    }
  }

  tags = local.tags
}

resource "aws_cloudwatch_event_rule" "rebuilder_schedule" {
  count               = var.enable_rebuilder_schedule ? 1 : 0
  name                = "${local.name_prefix}-rebuilder-schedule"
  schedule_expression = var.rebuilder_schedule_rate
  tags                = local.tags
}

resource "aws_cloudwatch_event_target" "rebuilder_target" {
  count     = var.enable_rebuilder_schedule ? 1 : 0
  rule      = aws_cloudwatch_event_rule.rebuilder_schedule[0].name
  target_id = "rebuilder"
  arn       = aws_lambda_function.leaderboard_rebuilder.arn
}

resource "aws_lambda_permission" "allow_events_rebuilder" {
  count         = var.enable_rebuilder_schedule ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridgeRebuilder"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.leaderboard_rebuilder.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rebuilder_schedule[0].arn
}

resource "aws_lambda_function" "get_leaderboard" {
  function_name = "${local.name_prefix}-getleaderboard"
  role = aws_iam_role.get_leaderboard.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.14"
  timeout       = 10
  memory_size   = 256

  filename         = data.archive_file.getleaderboard_zip.output_path
  source_code_hash = data.archive_file.getleaderboard_zip.output_base64sha256
  environment {
    variables = {
      GLOBAL_LEADERBOARD_TABLE = aws_dynamodb_table.global_leaderboard.name
      LEADERBOARD_ID           = "GLOBAL"
      AS_OF                    = "LATEST"
    }
  }

  tags = local.tags
}

resource "aws_lambda_function_url" "get_leaderboard" {
  function_name      = aws_lambda_function.get_leaderboard.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["GET"]
    allow_headers = ["*"]
  }
}

resource "aws_lambda_permission" "allow_public_getleaderboard_url" {
  statement_id           = "AllowPublicInvokeFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.get_leaderboard.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}
