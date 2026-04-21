variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "secret_arn" {
  type = string
}

variable "event_bus_name" {
  type = string
}
