# Backend configuration
terraform {
  #required_version = ">= 0.13"

 backend "s3" {
    bucket         = "merisbuck123456"
    key            = "terraform/state"
    region         = "eu-central-1"
    dynamodb_table = "merihantable"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
  access_key = "secret"
  secret_key = "secret"
}

# Create VPC
resource "aws_vpc" "merihan_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "merihan_vpc"
  }
}

# Create Subnets
resource "aws_subnet" "merihan_subnet_1" {
  vpc_id                  = aws_vpc.merihan_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  tags = {
    Name = "merihan_subnet_1"
  }
}

resource "aws_subnet" "merihan_subnet_2" {
  vpc_id                  = aws_vpc.merihan_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-central-1b"
  tags = {
    Name = "merihan_subnet_2"
  }
}

# igw
resource "aws_internet_gateway" "merihan_igw" {
  vpc_id = aws_vpc.merihan_vpc.id
  tags = {
    Name = "merihan_igw"
  }
}

#  Route Table
resource "aws_route_table" "merihan_route_table" {
  vpc_id = aws_vpc.merihan_vpc.id
  route {
    cidr_block  = "0.0.0.0/0"
    gateway_id  = aws_internet_gateway.merihan_igw.id
  }
  tags = {
    Name = "merihan_route_table"
  }
}

resource "aws_route_table_association" "merihan_subnet_1_association" {
  subnet_id      = aws_subnet.merihan_subnet_1.id
  route_table_id = aws_route_table.merihan_route_table.id
}

resource "aws_route_table_association" "merihan_subnet_2_association" {
  subnet_id      = aws_subnet.merihan_subnet_2.id
  route_table_id = aws_route_table.merihan_route_table.id
}

# Create Security Group
resource "aws_security_group" "merihan_sg" {
  vpc_id = aws_vpc.merihan_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "merihan_sg"
  }
}

# Create Application Load Balancer (ALB)
resource "aws_lb" "merihan_alb" {
  name               = "merihan-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.merihan_sg.id]
  subnets            = [aws_subnet.merihan_subnet_1.id, aws_subnet.merihan_subnet_2.id]

  tags = {
    Name = "merihan_alb"
  }
}

resource "aws_lb_target_group" "merihan_target_group" {
  name        = "merihan-targets"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.merihan_vpc.id
  target_type = "instance"

  health_check {
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "merihan_target_group"
  }
}

resource "aws_lb_listener" "merihan_listener" {
  load_balancer_arn = aws_lb.merihan_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.merihan_target_group.arn
  }
}

# Create EC2 Instances
resource "aws_instance" "merihan_web" {
  count          = 2
  ami            = "ami-09042b2f6d07d164a"
  instance_type  = "t2.micro"
  subnet_id      = element([aws_subnet.merihan_subnet_1.id, aws_subnet.merihan_subnet_2.id], count.index)
  vpc_security_group_ids = [aws_security_group.merihan_sg.id]
  key_name       = "mykey" 

  tags = {
    Name = "merihan_web_${count.index + 1}"
  }

  user_data = <<-EOF
        #!/bin/bash


sudo apt-get update -y
sudo apt-get install -y nginx-full
sudo systemctl start nginx
sudo systemctl enable nginx
sudo apt-get install -y docker
sudo apt-get install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
usermod -aG docker ubuntu


# Pull and run a Docker container (e.g., Nginx for testing)
docker run -d -p 80:80 --name my_web_container nginx

# Restart Nginx to ensure it's running correctly
systemctl restart nginx

          EOF
}

# Create ECR Repository
resource "aws_ecr_repository" "merihan_ecr" {
  name                 = "merihan-ecr-repo"
  image_tag_mutability = "MUTABLE"
  tags = {
    Name = "merihan_ecr"
  }
}

