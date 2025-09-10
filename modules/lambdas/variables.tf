variable "project_name" { type = string }
variable "environment" { type = string }

variable "connections_table" { type = string } # p.ej. Connections-farmacia-dev
variable "orders_table" { type = string }      # p.ej. Orders-farmacia-dev

# SNS dual (admin / client)
variable "sns_topic_admin_arn" { type = string }
variable "sns_topic_client_arn" { type = string }

variable "websocket_callback_url" {
  type    = string
  default = ""
}



# Opcional: timeout común
variable "lambda_timeout" {
  type    = number
  default = 10
}
