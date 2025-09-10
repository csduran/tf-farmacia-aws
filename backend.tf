terraform {
  backend "s3" {
    bucket               = "tf-state-use1-423623827280"
    region               = "us-east-1"
    dynamodb_table       = "terraform-locks"
    encrypt              = true
    workspace_key_prefix = "farmacia"
    key                  = "terraform.tfstate"
  }
}
