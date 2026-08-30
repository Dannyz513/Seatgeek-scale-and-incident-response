data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

locals {
  user_data = <<-EOF
    #!/bin/bash
    dnf install -y nginx
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    echo "<h1>Ticket Platform</h1><p>Served by: $INSTANCE_ID</p>" > /usr/share/nginx/html/index.html
    systemctl enable nginx
    systemctl start nginx
  EOF
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.app.id]
  user_data               = base64encode(local.user_data)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-instance"
    }
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  min_size            = var.steady_state_capacity
  max_size            = var.peak_capacity
  desired_capacity    = var.steady_state_capacity

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.app.arn]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }
}

# --- Reactive scaling: responds to actual request load, not CPU ---
resource "aws_autoscaling_policy" "request_count_scaling" {
  name                   = "${var.project_name}-request-count-scaling"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type             = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label          = "${aws_lb.app.arn_suffix}/${aws_lb_target_group.app.arn_suffix}"
    }
    target_value = 100
  }
}

# --- Scheduled pre-warming: an example scheduled action for a known on-sale time ---
resource "aws_autoscaling_schedule" "prewarm_for_onsale" {
  scheduled_action_name  = "${var.project_name}-prewarm-onsale"
  autoscaling_group_name = aws_autoscaling_group.app.name
  min_size               = var.peak_capacity
  max_size               = var.peak_capacity
  desired_capacity       = var.peak_capacity
  # Example: 10:00 UTC on a known on-sale date - in practice this would be
  # set dynamically per event, or via an internal scheduling tool
  start_time = "2026-12-01T10:00:00Z"
}

resource "aws_lb" "app" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
    timeout             = 5
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