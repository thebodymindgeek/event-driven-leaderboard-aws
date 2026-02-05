variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "edl"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "owner" {
  type    = string
  default = "marwa"
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}

variable "notification_email" {
  type        = string
  description = "Email to subscribe to SNS notifications"
}

variable "processor_timeout_seconds" {
  type    = number
  default = 240
}

variable "processor_memory_mb" {
  type    = number
  default = 256
}

variable "sqs_visibility_timeout_seconds" {
  type    = number
  default = 240
}

variable "sqs_age_oldest_seconds_threshold" {
  type    = number
  default = 120
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "enable_rebuilder_schedule" {
  type    = bool
  default = true
}

variable "rebuilder_schedule_rate" {
  type    = string
  default = "rate(5 minute)"
}
variable "dashboard_html_path" {
  type        = string
  description = "Path to dashboard index.html"
  default     = "../dashboard/index.html"
}