variable "environment" {
    description = "Environment"
    type = string
    default = "dev"
}

variable "prefix" {
    description = "prefix"
    type = string
    default = "tf2t"
}
variable "container_name" {
  description = "Container name"
  type = string
  default = "2tier-app"
}

variable "app_image" {
  description = "App image"
  type = string
  default = "990533295098.dkr.ecr.us-east-1.amazonaws.com/dev-2ft:latest"
}

variable "port" {
  description = "Port"
  type = number
  default = 8000
}

variable "cpu" {
  description = "CPU"
  type = number
  default = 512  
}

variable "memory" {
  description = "Memory"
  type = number
  default = 1024
}

variable "ecs_task_def" {
  description = "ECS task definition"
  type = string
  default = "2tier-appjuly"
}

variable "aws_region" {
  description = "AWS region"
  type = string
  default = "us-east-1"
}

variable "domain_name" {
  default = "devopswithraj.space"
     
}

variable "subdomain_name" {
  default = "tf2t"
     
}