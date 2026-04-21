variable "secret_name" {
  type = string
}

variable "secret_string_json" {
  type      = string
  sensitive = true
}

variable "kms_alias" {
  type = string
}