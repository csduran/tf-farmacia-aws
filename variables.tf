variable "project_name" { type = string }
variable "environment" { type = string }
variable "region" { type = string }

# Correos como listas (coinciden con messaging_dual)
variable "admin_emails" { type = list(string) }
variable "client_emails" { type = list(string) }
