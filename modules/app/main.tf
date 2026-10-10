# ---------- IAM: least-privilege role for the app tier ----------

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name_prefix        = "${var.name}-app-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Session Manager access instead of SSH keys and port 22
resource "aws_iam_role_policy_attachment" "app_ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Read only the one secret that holds the DB credentials
data "aws_iam_policy_document" "read_db_secret" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.db_secret_arn]
  }
}

resource "aws_iam_role_policy" "read_db_secret" {
  name   = "read-db-secret"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.read_db_secret.json
}

resource "aws_iam_instance_profile" "app" {
  name_prefix = "${var.name}-app-"
  role        = aws_iam_role.app.name
}

# ---------- Internal ALB (web tier -> app tier) ----------

resource "aws_lb" "app" {
  name               = "${var.name}-app-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.app_alb_sg_id]
  subnets            = var.app_subnet_ids
}

resource "aws_lb_target_group" "app" {
  name                 = "${var.name}-app-tg"
  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = "/api/health"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ---------- Launch template + Auto Scaling group ----------

resource "aws_launch_template" "app" {
  name_prefix   = "${var.name}-app-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [var.app_sg_id]

  iam_instance_profile {
    arn = aws_iam_instance_profile.app.arn
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    app_py        = file("${path.module}/app.py")
    region        = var.region
    db_host       = var.db_host
    db_name       = var.db_name
    db_secret_arn = var.db_secret_arn
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.name}-app", Tier = "app" }
  }

  update_default_version = true
}

resource "aws_autoscaling_group" "app" {
  name                      = "${var.name}-app-asg"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.min_size
  vpc_zone_identifier       = var.app_subnet_ids
  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-app"
    propagate_at_launch = true
  }

  # Let the scaling policy own the instance count after creation
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# Add or remove instances to keep average CPU around 50%
resource "aws_autoscaling_policy" "app_cpu" {
  name                   = "${var.name}-app-cpu50"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50
  }
}
