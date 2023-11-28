/* # # # # # # # # # # # #
- Security Group         #
- Launch Configuration   #
- AutoScalling Group     #
- Elastic Load Balancer  #
                         #
^Create by Vygovskiy ^     #
*/ # # # # # # # # # # # #

provider "aws" {
  access_key = ""
  secret_key = ""
  region     = "us-east-1"
}

data "aws_availability_zones" "available" {}
data "aws_ami" "latest_anazon_linux" {
  owners      = ["137112412989"]
  most_recent = true
  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }
}

/*Security Group*/

resource "aws_security_group" "web" {
  name = "Dynamic Security Group"
  dynamic "ingress" {
    for_each = ["80", "443"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "Dynamic SecurityGroup"
    Owner = "Vygovskiy Vladislav"
  }
}

/*Launch Configuration*/

resource "aws_launch_configuration" "web" {
  //name = "WebServer-Highly-Available-LC"
  name_prefix     = "WebServer-Highly-Available-LC-"
  image_id        = data.aws_ami.latest_anazon_linux.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.web.id]
  user_data       = file("user-data.sh")

  lifecycle {
    create_before_destroy = true
  }
}

#AutoScalling Group

resource "aws_autoscaling_group" "web" {
  name                 = "ASG-${aws_launch_configuration.web.name}"
  max_size             = 2
  min_size             = 2
  min_elb_capacity     = 2
  health_check_type    = "ELB"
  vpc_zone_identifier  = [aws_default_subnet.default_az1.id, aws_default_subnet.default_az2.id]
  load_balancers       = [aws_elb.web.name]
  launch_configuration = aws_launch_configuration.web.name
  dynamic "tag" {
    for_each = {
      Name = "WebServer-in-ASG"

    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  lifecycle {
    create_before_destroy = true
  }

}

#Elastic Load Balancer

resource "aws_elb" "web" {
  name               = "WebServer-HA-ELB"
  availability_zones = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  security_groups    = [aws_security_group.web.id]
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }


  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 10
  }

  tags = {
    Name = "WebServer-HA-ELB"
  }
}

# Default Subnet

resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available.names[0]
}

resource "aws_default_subnet" "default_az2" {
  availability_zone = data.aws_availability_zones.available.names[1]
}

output "web_loadbalancer_url" {
  value = aws_elb.web.dns_name
}
