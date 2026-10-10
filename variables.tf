variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for all resources (must start with a letter)"
  type        = string
  default     = "threetier"
}

variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "azs" {
  description = "Two or more Availability Zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.1.0/24", "10.10.2.0/24"]
}

variable "app_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.11.0/24", "10.10.12.0/24"]
}

variable "db_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.21.0/24", "10.10.22.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for the web and app tiers"
  type        = string
  default     = "t3.micro"
}

variable "web_min_size" {
  type    = number
  default = 2
}

variable "web_max_size" {
  type    = number
  default = 4
}

variable "app_min_size" {
  type    = number
  default = 2
}

variable "app_max_size" {
  type    = number
  default = 4
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "appadmin"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_multi_az" {
  description = "Run a standby RDS instance in a second AZ (roughly doubles the DB cost)"
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  description = "Days to keep automated backups (0 disables backups)"
  type        = number
  default     = 7
}
