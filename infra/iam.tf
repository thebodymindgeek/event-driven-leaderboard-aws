data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "pipes_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["pipes.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "activity_processor" {
  name               = "${local.name_prefix}-activity-processor-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "ap_basic" {
  role       = aws_iam_role.activity_processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "ap_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:UpdateItem"
    ]
    resources = [
      aws_dynamodb_table.processed_events.arn,
      aws_dynamodb_table.program_progress.arn,
      aws_dynamodb_table.employee_totals.arn
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.notif.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ChangeMessageVisibility"
    ]
    resources = [aws_sqs_queue.activities_q.arn]
  }
}

resource "aws_iam_policy" "ap_policy" {
  name   = "${local.name_prefix}-activity-processor-policy"
  policy = data.aws_iam_policy_document.ap_policy.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "ap_attach" {
  role       = aws_iam_role.activity_processor.name
  policy_arn = aws_iam_policy.ap_policy.arn
}

resource "aws_iam_role" "rebuilder" {
  name               = "${local.name_prefix}-leaderboard-rebuilder-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "rb_basic" {
  role       = aws_iam_role.rebuilder.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "rb_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:Query",
      "dynamodb:PutItem"
    ]
    resources = [
      aws_dynamodb_table.employee_totals.arn,
      "${aws_dynamodb_table.employee_totals.arn}/index/GSI_Leaderboard",
      aws_dynamodb_table.global_leaderboard.arn
    ]
  }
}

resource "aws_iam_policy" "rb_policy" {
  name   = "${local.name_prefix}-leaderboard-rebuilder-policy"
  policy = data.aws_iam_policy_document.rb_policy.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "rb_attach" {
  role       = aws_iam_role.rebuilder.name
  policy_arn = aws_iam_policy.rb_policy.arn
}

resource "aws_iam_role" "simulator" {
  name               = "${local.name_prefix}-activity-simulator-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "sim_basic" {
  role       = aws_iam_role.simulator.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "sim_policy" {
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.activities.arn]
  }
}

resource "aws_iam_policy" "sim_policy" {
  name   = "${local.name_prefix}-activity-simulator-policy"
  policy = data.aws_iam_policy_document.sim_policy.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "sim_attach" {
  role       = aws_iam_role.simulator.name
  policy_arn = aws_iam_policy.sim_policy.arn
}

resource "aws_iam_role" "pipes" {
  name               = "${local.name_prefix}-pipes-role"
  assume_role_policy = data.aws_iam_policy_document.pipes_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "pipes_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:DescribeStream",
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
      "dynamodb:ListStreams"
    ]
    resources = [aws_dynamodb_table.activities.stream_arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.activities_q.arn]
  }
}

resource "aws_iam_policy" "pipes_policy" {
  name   = "${local.name_prefix}-pipes-policy"
  policy = data.aws_iam_policy_document.pipes_policy.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "pipes_attach" {
  role       = aws_iam_role.pipes.name
  policy_arn = aws_iam_policy.pipes_policy.arn
}

# -------------------------
# GetLeaderboard Lambda IAM
# -------------------------
resource "aws_iam_role" "get_leaderboard" {
  name               = "${local.name_prefix}-getleaderboard-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "gl_basic" {
  role       = aws_iam_role.get_leaderboard.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "gl_policy" {
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:GetItem"]
    resources = [aws_dynamodb_table.global_leaderboard.arn]
  }
}

resource "aws_iam_policy" "gl_policy" {
  name   = "${local.name_prefix}-getleaderboard-policy"
  policy = data.aws_iam_policy_document.gl_policy.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "gl_attach" {
  role       = aws_iam_role.get_leaderboard.name
  policy_arn = aws_iam_policy.gl_policy.arn
}