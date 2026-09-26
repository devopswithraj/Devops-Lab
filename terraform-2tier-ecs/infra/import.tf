import {
  to = aws_ecr_repository.ecr_repo
  # dev-tf2t
  id = "${var.environment}-${var.prefix}"
}

#terraform plan -generate-config-out=ecr.tf