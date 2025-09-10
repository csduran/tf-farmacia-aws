
output "admin_topic_arn" {
  value = aws_sns_topic.admin.arn
}

output "client_topic_arn" {
  value = aws_sns_topic.client.arn
}
