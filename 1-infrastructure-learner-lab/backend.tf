terraform {
  backend "s3" {
    encrypt        = true
    bucket         = "nt542-architecture"
    key            = "terraform/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}