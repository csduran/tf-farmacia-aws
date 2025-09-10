variable "table_name" {
  description = "Nombre de la tabla DynamoDB"
  type        = string
}

variable "hash_key" {
  description = "Nombre del atributo clave de partición (HASH)"
  type        = string
}
