output "web_url" {
  description = "Open this in a browser to reach the app"
  value       = "http://${module.web.alb_dns_name}"
}

output "app_alb_dns" {
  description = "Internal ALB for the backend (only reachable inside the VPC)"
  value       = module.app.alb_dns_name
}

output "db_endpoint" {
  value = module.database.address
}

output "db_secret_arn" {
  description = "Secrets Manager secret holding the DB credentials"
  value       = module.database.secret_arn
}

output "vpc_id" {
  value = module.network.vpc_id
}
