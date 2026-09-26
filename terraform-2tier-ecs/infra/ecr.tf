# __generated__ by Terraform from "dev-tf2t"
resource "aws_ecr_repository" "ecr_repo" {
  name                 = "dev-2ft"
  region               = "us-east-1"
  force_delete = true
}