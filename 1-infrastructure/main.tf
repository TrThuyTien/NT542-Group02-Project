terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_cloudwatch_event_bus" "shared" {
  name = "${var.project_name}-bus"
}

module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  cidr_block           = var.cidr_block
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "ecr" {
  source           = "./modules/ecr"
  repository_name  = "${var.project_name}-app"
  scan_on_push     = true
  image_mutability = "MUTABLE"
}

module "secrets" {
  source             = "./modules/secrets"
  secret_name        = "${var.project_name}-app-secret"
  secret_string_json = var.secret_string_json
  kms_alias          = "${var.project_name}-kms"
}


module "ecs" {
  depends_on = [
    module.vpc,
    module.secrets,
    aws_cloudwatch_event_bus.shared
  ]

  source = "./modules/ecs"

  project_name = var.project_name

  vpc_id = module.vpc.vpc_id

  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  container_image = "${module.ecr.repository_url}:latest"
  container_port  = var.container_port

  desired_count = var.desired_count
  cpu           = var.ecs_cpu
  memory        = var.ecs_memory

  secret_arn     = module.secrets.secret_arn
  event_bus_name = aws_cloudwatch_event_bus.shared.name
}

module "lambda" {
  depends_on         = [module.vpc, aws_cloudwatch_event_bus.shared, module.secrets]
  source             = "./modules/lambda"
  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  secret_arn         = module.secrets.secret_arn
  event_bus_name     = aws_cloudwatch_event_bus.shared.name
}

