resource "aws_pipes_pipe" "ddb_stream_to_sqs" {
  name     = "${local.name_prefix}-activities-stream-to-sqs"
  role_arn = aws_iam_role.pipes.arn
  source   = aws_dynamodb_table.activities.stream_arn
  target   = aws_sqs_queue.activities_q.arn

  source_parameters {
    dynamodb_stream_parameters {
      starting_position                  = "LATEST"
      batch_size                         = 1
      maximum_batching_window_in_seconds = 0
    }

    filter_criteria {
      filter {
        pattern = jsonencode(
          {
            eventName = ["INSERT"]
          }
        )
      }
    }
  }

  tags = local.tags
}
