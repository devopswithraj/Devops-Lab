# rds subnet group

resource "aws_db_subnet_group" "default" {
  name       = "${var.environment}-${var.prefix}-rds-subnet-group"
  subnet_ids = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id]

  tags = {
    Name = "My DB subnet group"
  }
}

# rds password

resource "random_password" "password" {
  length           = 10
  special          = false
  override_special = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
}

# rds instance on that subnet group 
# ubnet group, SG, password, user, all the infor

resource "aws_db_instance" "rds_instance" {
  identifier              = "${var.environment}-${var.prefix}-rds"
  allocated_storage       = 20
  backup_retention_period = 7
  db_subnet_group_name    = aws_db_subnet_group.default.name
  engine                  = "postgres"
  engine_version          = local.postgres_version
  instance_class          = "db.t3.medium"
  db_name                 = var.prefix
  multi_az                = false # Custom for Oracle does not support multi-az
  password                = random_password.password.result
  username                = "postgres"
  storage_encrypted       = false
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]

  skip_final_snapshot = true
  tags = {
    Name = "${var.environment}-${var.prefix}-rds"
  }
}

# db_link = "postgresql://postgres:${random_password.password.result}@${aws_db_instance.rds_instance.address}/${aws_db_instance.rds_instance.db_name}"
# % terraform import aws_db_instance.rds_instance  



resource "aws_secretsmanager_secret" "rds_password" {
  name        = "${var.environment}-${var.prefix}-rds"
  description = "Password for rds instance"
}

# aws secret manager version for rds password

resource "aws_secretsmanager_secret_version" "rds_password" {
  secret_id = aws_secretsmanager_secret.rds_password.id
  # db_link = "postgresql://{user}:{password}@{host}:{port}/{database_name}"
  secret_string = "postgresql://postgres:${random_password.password.result}@${aws_db_instance.rds_instance.address}/${aws_db_instance.rds_instance.db_name}"
}