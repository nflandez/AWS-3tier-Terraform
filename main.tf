# Latest Amazon Linux 2023 AMI for the selected region (avoids hardcoded AMI IDs)
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

module "network" {
  source = "./modules/network"

  name                = var.name
  vpc_cidr            = var.vpc_cidr
  azs                 = var.azs
  public_subnet_cidrs = var.public_subnet_cidrs
  app_subnet_cidrs    = var.app_subnet_cidrs
  db_subnet_cidrs     = var.db_subnet_cidrs
}

module "security" {
  source = "./modules/security"

  name   = var.name
  vpc_id = module.network.vpc_id
}

module "database" {
  source = "./modules/database"

  name                  = var.name
  db_subnet_ids         = module.network.db_subnet_ids
  db_sg_id              = module.security.db_sg_id
  db_name               = var.db_name
  db_username           = var.db_username
  instance_class        = var.db_instance_class
  multi_az              = var.db_multi_az
  backup_retention_days = var.db_backup_retention_days
}

module "app" {
  source = "./modules/app"

  name           = var.name
  region         = var.region
  vpc_id         = module.network.vpc_id
  app_subnet_ids = module.network.app_subnet_ids
  app_alb_sg_id  = module.security.app_alb_sg_id
  app_sg_id      = module.security.app_sg_id
  ami_id         = data.aws_ssm_parameter.al2023.value
  instance_type  = var.instance_type
  min_size       = var.app_min_size
  max_size       = var.app_max_size
  db_host        = module.database.address
  db_name        = var.db_name
  db_secret_arn  = module.database.secret_arn

  # App instances install packages at boot, so the NAT gateway route must exist first
  depends_on = [module.network]
}

module "web" {
  source = "./modules/web"

  name              = var.name
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  web_alb_sg_id     = module.security.web_alb_sg_id
  web_sg_id         = module.security.web_sg_id
  ami_id            = data.aws_ssm_parameter.al2023.value
  instance_type     = var.instance_type
  min_size          = var.web_min_size
  max_size          = var.web_max_size
  app_alb_dns       = module.app.alb_dns_name
}
