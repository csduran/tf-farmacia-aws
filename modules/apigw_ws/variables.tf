variable "project_name" { type = string }
variable "environment" { type = string }

variable "lambda_onconnect_arn" { type = string }
variable "lambda_ondisconnect_arn" { type = string }
variable "lambda_websocket_handler_arn" { type = string }
