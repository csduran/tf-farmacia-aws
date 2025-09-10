###############
# Datas & Locals
###############
data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  name_prefix       = "${var.project_name}-${var.environment}"
  lambda_invoke_uri = "arn:${data.aws_partition.current.partition}:apigateway:${data.aws_region.current.id}:lambda:path/2015-03-31/functions"
}

#########################
# API Gateway WebSocket
#########################
resource "aws_apigatewayv2_api" "ws_api" {
  name          = "${local.name_prefix}-ws"
  protocol_type = "WEBSOCKET"
  # El frontend envía {"tipo": "..."}; si no, cae en $default
  route_selection_expression = "$request.body.tipo"
}

################
# Integraciones
################
resource "aws_apigatewayv2_integration" "connect_integ" {
  api_id                 = aws_apigatewayv2_api.ws_api.id
  integration_type       = "AWS_PROXY"
  connection_type        = "INTERNET"
  integration_uri        = "${local.lambda_invoke_uri}/${var.lambda_onconnect_arn}/invocations"
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_integration" "disconnect_integ" {
  api_id                 = aws_apigatewayv2_api.ws_api.id
  integration_type       = "AWS_PROXY"
  connection_type        = "INTERNET"
  integration_uri        = "${local.lambda_invoke_uri}/${var.lambda_ondisconnect_arn}/invocations"
  payload_format_version = "1.0"
}

# Única integración para todas las acciones ($default incluido)
resource "aws_apigatewayv2_integration" "handler_integ" {
  api_id                 = aws_apigatewayv2_api.ws_api.id
  integration_type       = "AWS_PROXY"
  connection_type        = "INTERNET"
  integration_uri        = "${local.lambda_invoke_uri}/${var.lambda_websocket_handler_arn}/invocations"
  payload_format_version = "1.0"
}

#########
# Rutas
#########
resource "aws_apigatewayv2_route" "connect" {
  api_id    = aws_apigatewayv2_api.ws_api.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.connect_integ.id}"
}

resource "aws_apigatewayv2_route" "disconnect" {
  api_id    = aws_apigatewayv2_api.ws_api.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.disconnect_integ.id}"
}

# Rutas de negocio (coinciden con 'tipo' del body)
resource "aws_apigatewayv2_route" "neworder" {
  api_id    = aws_apigatewayv2_api.ws_api.id
  route_key = "newOrder"
  target    = "integrations/${aws_apigatewayv2_integration.handler_integ.id}"
}

resource "aws_apigatewayv2_route" "updateorder" {
  api_id    = aws_apigatewayv2_api.ws_api.id
  route_key = "updateOrder"
  target    = "integrations/${aws_apigatewayv2_integration.handler_integ.id}"
}

resource "aws_apigatewayv2_route" "getpedidos" {
  api_id    = aws_apigatewayv2_api.ws_api.id
  route_key = "getPedidos"
  target    = "integrations/${aws_apigatewayv2_integration.handler_integ.id}"
}

# Para evitar "Forbidden" cuando no hay 'tipo' o no coincide
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.ws_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.handler_integ.id}"
}

#########
# Stage
#########
resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.ws_api.id
  name        = var.environment # o "dev"
  auto_deploy = true
  # SIN access_log_settings (sin logs en CloudWatch) → evita error 400
}

#########################
# Permisos Lambda → APIGW
#########################
resource "aws_lambda_permission" "allow_connect" {
  statement_id  = "AllowAPIGWConnect-${aws_apigatewayv2_stage.stage.name}"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_onconnect_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ws_api.execution_arn}/${aws_apigatewayv2_stage.stage.name}/*"
}

resource "aws_lambda_permission" "allow_disconnect" {
  statement_id  = "AllowAPIGWDisconnect-${aws_apigatewayv2_stage.stage.name}"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_ondisconnect_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ws_api.execution_arn}/${aws_apigatewayv2_stage.stage.name}/*"
}

resource "aws_lambda_permission" "allow_handler" {
  statement_id  = "AllowAPIGWHandler-${aws_apigatewayv2_stage.stage.name}"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_websocket_handler_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ws_api.execution_arn}/${aws_apigatewayv2_stage.stage.name}/*"
}
