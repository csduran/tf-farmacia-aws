output "lambda_onconnect_arn" {
  value = aws_lambda_function.onconnect.arn
}

output "lambda_ondisconnect_arn" {
  value = aws_lambda_function.ondisconnect.arn
}

output "lambda_websocket_handler_arn" {
  value = aws_lambda_function.websocket_handler.arn
}
