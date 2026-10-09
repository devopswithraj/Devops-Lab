# ALB resources
resource "aws_lb" "ecs-alb" {
  name               = "${var.environment}-${var.prefix}-ecs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]

  tags = {
    Name = "${var.environment}-${var.prefix}-ecs-alb"
  }
}

resource "aws_lb_target_group" "ecs-target" {
  name        = "${var.environment}-${var.prefix}-ecs-target-ip"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_lb_listener" "ecs-listener-https" {
  load_balancer_arn = aws_lb.ecs-alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-east-1:990533295098:certificate/b0a2021c-3ef0-4b2a-b745-2c3102de03cc"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs-target.arn
  }
}

resource "aws_lb_listener" "ecs-listener-http" {
  load_balancer_arn = aws_lb.ecs-alb.arn
  port              = "80"
  protocol          = "HTTP"


  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}