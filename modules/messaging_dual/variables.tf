variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

# Correos para trabajadores/admin
variable "admin_emails" {
  type    = list(string)
  default = []
}

# Correos para clientes
variable "client_emails" {
  type    = list(string)
  default = []
}
