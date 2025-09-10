
locals {
  prefix = "${var.project_name}-${var.environment}"
}

# Topic para trabajadores/admin
resource "aws_sns_topic" "admin" {
  name = "${local.prefix}-notifications-admin"
}

# Topic para clientes
resource "aws_sns_topic" "client" {
  name = "${local.prefix}-notifications-client"
}

# Suscripciones email (admin)
resource "aws_sns_topic_subscription" "admin_email" {
  for_each  = toset(var.admin_emails)
  topic_arn = aws_sns_topic.admin.arn
  protocol  = "email"
  endpoint  = each.value
}

# Suscripciones email (cliente)
resource "aws_sns_topic_subscription" "client_email" {
  for_each  = toset(var.client_emails)
  topic_arn = aws_sns_topic.client.arn
  protocol  = "email"
  endpoint  = each.value
}
