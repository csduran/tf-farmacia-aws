terraform {
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    aws = {
      source = "hashicorp/aws"
      # la versión viene fijada en el root; aquí no forzamos
    }
  }
}
