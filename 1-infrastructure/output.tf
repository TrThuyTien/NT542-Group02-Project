output "alb_dns_name" {
  value = module.ecs.alb_dns_name
}

output "event_bus_name" {
  value = aws_cloudwatch_event_bus.shared.name
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}