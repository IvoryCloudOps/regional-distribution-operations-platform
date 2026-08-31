resource "aws_lb" "distribution_internal_alb" {
  name               = "distribution-internal-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.distribution_alb_sg.id]
  subnets            = [aws_subnet.distribution_public_a.id, aws_subnet.distribution_public_b.id]

  tags = {
    Name        = "distribution-internal-alb"
    environment = "development"
    managed_by  = "Terraform"
  }
}

resource "aws_lb_target_group" "distribution_app_tg" {
  name     = "distribution-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.distribution_vpc.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name        = "distribution-app-tg"
    environment = "development"
    managed_by  = "Terraform"
  }
}

resource "aws_lb_listener" "distribution_http" {
  load_balancer_arn = aws_lb.distribution_internal_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.distribution_app_tg.arn

  }
}

