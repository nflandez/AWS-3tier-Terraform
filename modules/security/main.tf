# Traffic flows in one direction only:
# Internet -> web ALB (80) -> web EC2 (80) -> app ALB (80) -> app EC2 (8080) -> RDS (3306)
# Each tier accepts traffic only from the security group of the tier in front of it.
# No SSH (22) is opened anywhere; instances are reached with SSM Session Manager.

resource "aws_security_group" "web_alb" {
  name        = "${var.name}-web-alb-sg"
  description = "Public ALB: HTTP from the internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-web-alb-sg" }
}

resource "aws_security_group" "web" {
  name        = "${var.name}-web-sg"
  description = "Web tier EC2: HTTP only from the public ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from web ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web_alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-web-sg" }
}

resource "aws_security_group" "app_alb" {
  name        = "${var.name}-app-alb-sg"
  description = "Internal ALB: HTTP only from the web tier"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from web EC2"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-app-alb-sg" }
}

resource "aws_security_group" "app" {
  name        = "${var.name}-app-sg"
  description = "App tier EC2: port 8080 only from the internal ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App port from internal ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.app_alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-app-sg" }
}

resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "RDS: MySQL only from the app tier"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from app EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  tags = { Name = "${var.name}-db-sg" }
}
