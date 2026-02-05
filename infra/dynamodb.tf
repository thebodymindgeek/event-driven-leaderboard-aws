resource "aws_dynamodb_table" "activities" {
  name         = "${local.name_prefix}-Activities"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "employee_id"
  range_key = "ts_event"

  attribute {
    name = "employee_id"
    type = "S"
  }

  attribute {
    name = "ts_event"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"

  tags = local.tags
}

resource "aws_dynamodb_table" "programs" {
  name         = "${local.name_prefix}-Programs"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "program_id"

  attribute {
    name = "program_id"
    type = "S"
  }

  tags = local.tags
}

resource "aws_dynamodb_table" "program_progress" {
  name         = "${local.name_prefix}-ProgramProgress"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "employee_id"
  range_key = "program_id"

  attribute {
    name = "employee_id"
    type = "S"
  }

  attribute {
    name = "program_id"
    type = "S"
  }

  tags = local.tags
}

resource "aws_dynamodb_table" "processed_events" {
  name         = "${local.name_prefix}-ProcessedEvents"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = local.tags
}

resource "aws_dynamodb_table" "employee_totals" {
  name         = "${local.name_prefix}-EmployeeTotals"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "employee_id"
  range_key = "scope"

  attribute {
    name = "employee_id"
    type = "S"
  }

  attribute {
    name = "scope"
    type = "S"
  }

  attribute {
    name = "leaderboard_id"
    type = "S"
  }

  attribute {
    name = "total_points"
    type = "N"
  }

  global_secondary_index {
    name            = "GSI_Leaderboard"
    hash_key        = "leaderboard_id"
    range_key       = "total_points"
    projection_type = "ALL"
  }

  tags = local.tags
}

resource "aws_dynamodb_table" "global_leaderboard" {
  name         = "${local.name_prefix}-GlobalLeaderboard"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "leaderboard_id"
  range_key = "as_of"

  attribute {
    name = "leaderboard_id"
    type = "S"
  }

  attribute {
    name = "as_of"
    type = "S"
  }

  tags = local.tags
}
