provider "aws" {
  region  = "us-east-1"
  profile = "sparsh"
}

resource "aws_vpc" "infra2208-vpc" {
  cidr_block = "192.168.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "infra2208-vpc"
  }
}

resource "aws_subnet" "infra2208-public-subnet" {
  availability_zone = "us-east-1a"
  cidr_block = "192.168.0.0/24"
  map_public_ip_on_launch = true
  vpc_id = "${aws_vpc.infra2208-vpc.id}"
  tags = {
    Name = "infra2208-public-subnet"
  }
}

resource "aws_subnet" "infra2208-private-subnet" {
  availability_zone = "us-east-1b"
  cidr_block = "192.168.1.0/24"
  vpc_id = "${aws_vpc.infra2208-vpc.id}"
  tags = {
    Name = "infra2208-private-subnet"
  }
}


resource "aws_internet_gateway" "infra2208-ig" {
  vpc_id = "${aws_vpc.infra2208-vpc.id}"
  tags = {
    Name = "infra2208-ig"
  }
}

resource "aws_route_table" "infra2208-route-table" {
  vpc_id = "${aws_vpc.infra2208-vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.infra2208-ig.id}"
  }
  tags = {
    Name = "infra2208-route-table"
  }
}

resource "aws_route_table_association" "infra2208-route-ass" {
  subnet_id = "${aws_subnet.infra2208-public-subnet.id}"
  route_table_id = "${aws_route_table.infra2208-route-table.id}"
}

resource "tls_private_key" "private-key" {
    algorithm = "RSA"
    rsa_bits  = 4096
}

resource "aws_key_pair" "infra2208-key" {
    key_name   = "infra2208-key"
    public_key = tls_private_key.private-key.public_key_openssh
}

resource "local_file" "localkey" {
  filename = "infra2208-key"
  content = "${tls_private_key.private-key.private_key_pem}"
}

resource "aws_security_group" "infra2208-sg-wp" {
  depends_on = [aws_vpc.infra2208-vpc]
  name        = "infra2208-sg-wp"
  description = "Allow HTTP inbound traffic"
  vpc_id = "${aws_vpc.infra2208-vpc.id}"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
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
    Name = "infra2208-sg-wp"
  }
}

resource "aws_security_group" "infra2208-sg-sql" {
  depends_on = [aws_vpc.infra2208-vpc]
  name        = "infra2208-sg-sql"
  description = "Allow MySQL inbound traffic"
  vpc_id = "${aws_vpc.infra2208-vpc.id}"

  ingress {
    description = "HTTP"
    from_port   = 3306
    to_port     = 3306
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
    Name = "infra2208-sg-sql"
  }
}

resource "aws_instance" "infra2208-instance-wp" {
  //ami = "ami-000cbce3e1b899ebd"
  ami = "ami-0992aa883aea2dbb2"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.infra2208-public-subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.infra2208-sg-wp.id}"] 
  key_name = "${aws_key_pair.infra2208-key.key_name}"
  
  tags = {
    Name = "infra2208-instance-wp"
  }
}

resource "aws_instance" "infra2208-instance-sql" {
  //ami = "ami-08706cb5f68222d09"
  ami = "ami-0761dd91277e34178"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.infra2208-private-subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.infra2208-sg-sql.id}"] 
  key_name = "${aws_key_pair.infra2208-key.key_name}"
  
  tags = {
    Name = "infra2208-instance-sql"
  }
}

resource "null_resource" "run" {
  depends_on = [aws_instance.infra2208-instance-wp,aws_instance.infra2208-instance-sql]  

  provisioner "local-exec" {
    command = "start chrome ${aws_instance.infra2208-instance-wp.public_ip}"
  }
}