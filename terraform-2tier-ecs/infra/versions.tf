terraform {
  required_version = "1.16.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
      # ~> vs >= is used to specify the range of versions
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
