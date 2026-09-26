
# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Terraform = "true"
      Repo = "devops-lab/terraform-2tier-ecs"
}
  }
}

terraform {
  backend "s3" {
    bucket = "tfrm-state-bucket"
    key = "terraform-2tier-ecs/infra/terraform.tfstate"
    region = "us-east-1"
    use_lockfile = true
    encrypt = true
    kms_key_id = "arn:aws:kms:us-east-1:990533295098:key/05af6480-52f1-4873-ad8b-f4f244cca78f"
  }
}

