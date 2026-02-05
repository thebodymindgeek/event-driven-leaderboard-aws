locals {
  name_prefix = "${var.project}-${var.env}"

  tags = merge(
    {
      Project     = var.project
      Environment = var.env
      Owner       = var.owner
      ManagedBy   = "terraform"
    },
    var.extra_tags
  )
}
