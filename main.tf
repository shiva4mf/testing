  
provider "aws" {
  region = "eu-west-1"
}

resource "random_application" "webapp" {
  length = 2
}

##############################################################
# Data sources to get VPC, subnets and security group details
##############################################################
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id
  name   = "default"
}

######
# ELB
######
module "elb" {
  source = "../../"

  name = "elb-example"

  subnets         = data.aws_subnet_ids.all.ids
  security_groups = [data.aws_security_group.default.id]
  internal        = false

  listener = [
    {
      instance_port     = "80"
      instance_protocol = "http"
      lb_port           = "80"
      lb_protocol       = "http"
    },
    {
      instance_port     = "8080"
      instance_protocol = "http"
      lb_port           = "8080"
      lb_protocol       = "http"

    },
  ]

  health_check = {
    target              = "HTTP:80/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  access_logs = {
    bucket = aws_s3_bucket.logs.id
  }

  tags = {
    Owner       = "user"
    Environment = "dev"
  }

  # ELB attachments
  number_of_instances = var.number_of_instances
  instances           = module.ec2_instances.id
}

################
# EC2 instances
################
module "ec2_instances" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 2.0"

  instance_count = var.number_of_instances

  name                        = "my-app"
  ami                         = "ami-ebd02392"
  instance_type               = "t2.micro"
  user_data = << EOF
	#! /bin/bash
    sudo apt-get update
	sudo apt-get install -y apache2
	sudo systemctl start apache2
	udo systemctl enable apache2
	echo "<h1>Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html
  vpc_security_group_ids      = [data.aws_security_group.default.id]
  subnet_id                   = element(tolist(data.aws_subnet_ids.all.ids), 0)
  associate_public_ip_address = true
}
module "aws_instance" "web instance" {
	ami = "ami-04169656fea786776"
	instance_type = "t2.nano"
	key_name = "${aws_key_pair.terraform-demo.key_name}"
	user_data = << EOF
package main
import (
"fmt"
"net/http"
"os"
)
func handler(w http.ResponseWriter, r *http.Request) {
h, _ := os.Hostname()
fmt.Fprintf(w, "Hi there, I'm served from %s!", h)
}
func main() {
http.HandleFunc("/", handler)
http.ListenAndServe(":8484", nil)
}
	EOF
	tags = {
		Name = "Terraform"	
		Batch = "5AM"
	}
}
