# ---------- IAM: web tier only needs Session Manager ----------

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "web" {
  name_prefix        = "${var.name}-web-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "web_ssm" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "web" {
  name_prefix = "${var.name}-web-"
  role        = aws_iam_role.web.name
}

# ---------- Public ALB (internet -> web tier) ----------

resource "aws_lb" "web" {
  name               = "${var.name}-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.web_alb_sg_id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "web" {
  name                 = "${var.name}-web-tg"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# ---------- Launch template + Auto Scaling group ----------

resource "aws_launch_template" "web" {
  name_prefix   = "${var.name}-web-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [var.web_sg_id]
  }

  iam_instance_profile {
    arn = aws_iam_instance_profile.web.arn
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    app_alb_dns = var.app_alb_dns
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.name}-web", Tier = "web" }
  }

  update_default_version = true
}

resource "aws_autoscaling_group" "web" {
  name                      = "${var.name}-web-asg"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.min_size
  vpc_zone_identifier       = var.public_subnet_ids
  target_group_arns         = [aws_lb_target_group.web.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 180

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-web"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_autoscaling_policy" "web_cpu" {
  name                   = "${var.name}-web-cpu50"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50
  }
}
