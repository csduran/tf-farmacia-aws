output "websocket_url" { value = module.ws_api.websocket_url }
output "ws_api_id" { value = module.ws_api.ws_api_id }
output "sns_topic_admin_arn" { value = module.messaging_dual.admin_topic_arn }
output "sns_topic_client_arn" { value = module.messaging_dual.client_topic_arn }
output "orders_table_name" { value = module.orders_table.table_name }
output "connections_table_name" { value = module.connections_table.table_name }
# En la raíz (p.ej. outputs.tf)
data "aws_region" "current" {}

output "apigw_management_url" {
  description = "Endpoint para boto3.client('apigatewaymanagementapi')"
  value       = "https://${module.ws_api.ws_api_id}.execute-api.${data.aws_region.current.id}.amazonaws.com/${terraform.workspace}"
}