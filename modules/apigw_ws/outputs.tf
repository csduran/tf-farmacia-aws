output "ws_api_id" {
  description = "API ID"
  value       = aws_apigatewayv2_api.ws_api.id
}

# Construido de forma estable, sin condicional
output "websocket_url" {
  description = "WSS URL"
  value       = "wss://${aws_apigatewayv2_api.ws_api.id}.execute-api.${data.aws_region.current.id}.amazonaws.com/${aws_apigatewayv2_stage.stage.name}"
}

output "apigw_management_url" {
  description = "URL base para apigatewaymanagementapi"
  value       = "https://${aws_apigatewayv2_api.ws_api.id}.execute-api.${data.aws_region.current.id}.amazonaws.com/${aws_apigatewayv2_stage.stage.name}"
}
