a. Import - Telling terraform that this resource already exists and asking terraform to manage it
 1. Terraform import - traditional method by first defining the teerform resource in .tf file and use CLI command to add existing resource write into state file.
  <!-- resource "aws_instance" "web" {
  # configuration
  } -->
Then import it:
    terraform import aws_instance.web i-0123456789abcdef

 2. Terraform 1.5+ supports terraform block directly in configuration.
    <!-- import {
    to = aws_instance.web
    id = "i-0123456789abcdef"
    }  -->
 
    With the resource:

    <!-- resource "aws_instance" "web" {
    # configuration
    } -->

    Run terraform plan and terraform appky

  3. Drift detection - Resources managed by terrsform but on top of it the parts which are manually addedd 

  4. If any change in the definition , for example. change of name of AWS_DB instance resource, the state file has to be updated manually by removing the entry of the exting name from state file and apply.

b. tfvars always takes precedence and values defined as defauls inside variables.tf will not be invoked. But, varialbles defined in command line takes highes priority

c. To build docker image from src file:
docker build --platform linux/amd64 -t "990533295098.dkr.ecr.us-east-1.amazonaws.com/dev-2ft:1.0" .

Container registry login:
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 990533295098.dkr.ecr.us-east-1.amazonaws.com

docker push command:
docker push 990533295098.dkr.ecr.us-east-1.amazonaws.com/dev-2ft:1.0