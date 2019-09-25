## vpc ##
resource "aws_vpc" "group7-users11-vpc" {
  cidr_block           = "111.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"
  tags                 = { 
        Name           = "group7-users11-vpc"
    }
}

## internet gateway ##
resource "aws_internet_gateway" "group7-users11-igw" {
  vpc_id               = "${aws_vpc.group7-users11-vpc.id}"
  tags                 = { 
        Name           = "group7-users11-igw"
    }
}

## subnet ##
resource "aws_subnet" "group7-users11-subnet-a" {
  vpc_id               = "${aws_vpc.group7-users11-vpc.id}"
  availability_zone    = "ap-northeast-1a"
  cidr_block           = "111.0.1.0/24"
  tags                 = { 
        Name           = "group7-users11-subnet-a"
    }
}

resource "aws_subnet" "group7-users11-subnet-b" {
  vpc_id               = "${aws_vpc.group7-users11-vpc.id}"
  availability_zone    = "ap-northeast-1c"
  cidr_block           = "111.0.2.0/24"
  tags                 = {  
         Name          = "group7-users11-subnet-b"
    }
}

## routing table ##
resource "aws_route_table" "group7-users11-rt" {
  vpc_id = "${aws_vpc.group7-users11-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.group7-users11-igw.id}"
  }
  
  tags         = {
    Name       = "group7-users11-rt"
  }
}

## subnet attach to rtb ##
resource "aws_route_table_association" "group7-users11-rtsub-a" {
  subnet_id      = "${aws_subnet.group7-users11-subnet-a.id}"
  route_table_id = "${aws_route_table.group7-users11-rt.id}"  
}

resource "aws_route_table_association" "group7-users11-rtsub-b" {
  subnet_id      = "${aws_subnet.group7-users11-subnet-b.id}"
  route_table_id = "${aws_route_table.group7-users11-rt.id}"  
}

resource "aws_default_security_group" "group7-users11-sg" {
  vpc_id = "${aws_vpc.group7-users11-vpc.id}"

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags          = { 
     Name       = "group7-users11-sg"
  }
} 

resource "aws_security_group" "group7-users11-web-sg" {
  name        = "webserverSecurutyGroup"
  description = "open ssh port for webserverSecurutyGroup"

  vpc_id = "${aws_vpc.group7-users11-vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags          = {
    Name        = "group7-users11-web-sg"
  }
}

resource "aws_default_network_acl" "group7-users11-nacl" {
  default_network_acl_id = "${aws_vpc.group7-users11-vpc.default_network_acl_id}"

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  subnet_ids = [
    "${aws_subnet.group7-users11-subnet-a.id}",
    "${aws_subnet.group7-users11-subnet-b.id}",
  ]
  
  tags       = { 
     Name    = "group7-users11-nacl"
      
  }
}

resource "aws_instance" "group7-users11-web1" {
  ami               = "ami-0ab3e16f9c414dee7"
  availability_zone = "ap-northeast-1a"
  instance_type     = "t2.micro"
  key_name = "user11_key"
  vpc_security_group_ids = [
    "${aws_security_group.group7-users11-web-sg.id}",
    "${aws_default_security_group.group7-users11-sg.id}",
  ]

  subnet_id                   = "${aws_subnet.group7-users11-subnet-a.id}"
  associate_public_ip_address = true
  tags                        = {
    Name                      = "group7-users11-web1"
      
  }
}

resource "aws_instance" "group7-users11-web2" {
  ami               = "ami-0ab3e16f9c414dee7"
  availability_zone = "ap-northeast-1c"
  instance_type     = "t2.micro"
  key_name = "user11_key"	
  vpc_security_group_ids = [
    "${aws_security_group.group7-users11-web-sg.id}",
    "${aws_default_security_group.group7-users11-sg.id}",
  ]
				
  subnet_id                   = "${aws_subnet.group7-users11-subnet-b.id}"
  associate_public_ip_address = true
  tags                        = {
     Name                     = "group7-users11-web2"
      
  }
}

resource "aws_alb" "group7-users11-frontend" {
  name            = "group7-users11-salb"
  internal        = false
  security_groups = ["${aws_security_group.group7-users11-web-sg.id}"]
  subnets         = [
    "${aws_subnet.group7-users11-subnet-a.id}",
    "${aws_subnet.group7-users11-subnet-b.id}"
  ]
  lifecycle { create_before_destroy = true }
  tags            = {
      Name        = "group7-users11-salb"
      
  }
}

resource "aws_alb_target_group" "group7-users11-frontendalb" {
  name     = "group7-users11-albtg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.group7-users11-vpc.id}"

  health_check {
    interval            = 30
    path                = "/"
    healthy_threshold   = 3
    unhealthy_threshold = 3				
  }
  tags     = {
      Name = "group7-users11-albtg"
      
  }
}

resource "aws_alb_target_group_attachment" "group7-users11-frontend1" {
  target_group_arn = "${aws_alb_target_group.group7-users11-frontendalb.arn}"
  target_id        = "${aws_instance.group7-users11-web1.id}"
  port             = 80
}

resource "aws_alb_target_group_attachment" "group7-users11-frontend2" {
  target_group_arn = "${aws_alb_target_group.group7-users11-frontendalb.arn}"
  target_id        = "${aws_instance.group7-users11-web2.id}"
  port             = 80
}

resource "aws_alb_listener" "group7-users11-http" {
  load_balancer_arn = "${aws_alb.group7-users11-frontend.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.group7-users11-frontendalb.arn}"
    type             = "forward"
  }
}

