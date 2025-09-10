locals {
  suffix = "${var.project_name}-${var.environment}"
}

# DynamoDB
module "connections_table" {
  source     = "./modules/dynamodb"
  table_name = "Connections-${local.suffix}"
  hash_key   = "connectionId"
}

module "orders_table" {
  source     = "./modules/dynamodb"
  table_name = "Orders-${local.suffix}"
  hash_key   = "orderId"
}

# SNS (dos tópicos)
module "messaging_dual" {
  source        = "./modules/messaging_dual"
  project_name  = var.project_name
  environment   = var.environment
  admin_emails  = var.admin_emails
  client_emails = var.client_emails
}

# Lambdas (3 funciones)
module "lambdas" {
  source            = "./modules/lambdas"
  project_name      = var.project_name
  environment       = var.environment
  connections_table = module.connections_table.table_name
  orders_table      = module.orders_table.table_name

  sns_topic_admin_arn  = module.messaging_dual.admin_topic_arn
  sns_topic_client_arn = module.messaging_dual.client_topic_arn

  # lo calcula el módulo ws_api; si tu módulo lambdas lo requiere, pásalo luego
  websocket_callback_url = "https://dummy" # (si tu módulo lo pide ahora; luego se reemplaza)
}

# API Gateway WebSocket
module "ws_api" {
  source       = "./modules/apigw_ws"
  project_name = var.project_name
  environment  = var.environment

  lambda_onconnect_arn         = module.lambdas.lambda_onconnect_arn
  lambda_ondisconnect_arn      = module.lambdas.lambda_ondisconnect_arn
  lambda_websocket_handler_arn = module.lambdas.lambda_websocket_handler_arn
}

# S3 sitio estático
module "static_site" {
  source       = "./modules/static_site"
  project_name = var.project_name
  environment  = var.environment
  index_doc    = "index.html"
  error_doc    = "index.html"
}


