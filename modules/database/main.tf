resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.db_subnet_ids
  tags       = { Name = "${var.name}-db-subnets" }
}

# Custom parameter group instead of the default, so settings can be tuned
resource "aws_db_parameter_group" "this" {
  name        = "${var.name}-mysql80"
  family      = "mysql8.0"
  description = "Custom MySQL 8.0 parameters for ${var.name}"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name}-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.instance_class

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username

  # RDS generates the password and stores it in Secrets Manager.
  # It never appears in Terraform code, variables, or outputs.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  parameter_group_name   = aws_db_parameter_group.this.name
  vpc_security_group_ids = [var.db_sg_id]
  publicly_accessible    = false

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_days
  backup_window           = "07:00-08:00"
  maintenance_window      = "sun:08:30-sun:09:30"

  auto_minor_version_upgrade = true
  apply_immediately          = true

  # Lab settings so `terraform destroy` works cleanly. Use deletion protection
  # and a final snapshot for anything real.
  deletion_protection = false
  skip_final_snapshot = true

  tags = { Name = "${var.name}-db" }
}
