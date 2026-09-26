# rds SG -> listen on 5432 from the security group of ECS
# ECS SG -> listen on app port (8000) from security group of ALB
# ALB SG -> listen on 80/443 from public 
# rds SG
resource "aws_security_group" "rds_sg" {
  name        = "${var.environment}-${var.prefix}-rds-sg"
  description = "RDS security group"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# ECS SG 
resource "aws_security_group" "ecs_sg" {
  name        = "${var.environment}-${var.prefix}-ecs-sg"
  description = "ECS security group"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# ALB SG
resource "aws_security_group" "alb_sg" {
  name        = "${var.environment}-${var.prefix}-alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}