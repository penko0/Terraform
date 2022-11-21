terraform {

  required_version = ">=1.3.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.35.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.2.3"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.3"
    }
  }
}
# Configure the AWS Provider
provider "aws" {
  region = "eu-central-1"
}

#Retrieve the list of AZs in the current AWS region
data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

# LAB 59 - Working with data blocks( this bucket is created in advance for lab purposes)
data "aws_s3_bucket" "data_bucket" {
  bucket = "data-lookup-bucket-pen"
}

# We create nea IAM policy for our test S3 bucket.
resource "aws_iam_policy" "policy" {
  name        = "data_bucket_policy"
  description = "Allow access to my bucket"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:Get*",
          "s3:List*"
        ],
        "Resource" : "${data.aws_s3_bucket.data_bucket.arn}"
      }
    ]
  })
}




# Terraform Data Block - Lookup Ubuntu 16.04
data "aws_ami" "ubuntu_16_04" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }
  owners = ["099720109477"]
}

#Defined local variables
locals {
  team        = "api_mgmt_dev"
  application = "corp_api"
  server_name = "EC2-${var.environment}-api-${var.variables_sub_az}"
}

locals {
  service_name = "Automation"
  app_team     = "Cloud Team"
  createdby    = "terraform"
}
locals {
  # Common tags to be assigned to all resources. Expressions in local values are not limited to literal constants; they can also reference other values in
  #the module in order to transform or combine them, including variables, resource attributes, or other local values.
  common_tags = {
    Name      = local.server_name
    Owner     = local.team
    App       = local.application
    Service   = local.service_name
    AppTeam   = local.app_team
    CreatedBy = local.createdby
  }
}

#Lab 60 Built-in functions
locals {
  maximum = max(var.num_1, var.num_2, var.num_3)
  minimum = min(var.num_1, var.num_2, var.num_3, 44, 20)
}
output "max_value" {
  value = local.maximum
}
output "min_value" {
  value = local.minimum
}

#LAB 61 Dynamic blocks
locals {
  ingress_rules = [{
    port        = 443
    description = "Port 443"
    },
    {
      port        = 80
      description = "Port 80"
    }
  ]
}

#Define the VPC 
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = upper(var.vpc_name) #We use "upper" funtion to make all letters CAPITAL.
    Environment = "demo_environment"
    Terraform   = upper("true")
    Region      = data.aws_region.current.name
  }
}

#Deploy the private subnets
resource "aws_subnet" "private_subnets" {
  for_each          = var.private_subnets
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value)
  availability_zone = tolist(data.aws_availability_zones.available.names)[each.value]

  tags = {
    Name      = each.key
    Terraform = "true"
  }
}

#Deploy the public subnets
resource "aws_subnet" "public_subnets" {
  for_each                = var.public_subnets
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value + 100)
  availability_zone       = tolist(data.aws_availability_zones.available.names)[each.value]
  map_public_ip_on_launch = true

  tags = {
    Name      = each.key
    Terraform = "true"
  }
}

#Create route tables for public and private subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
    #nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name      = "demo_public_rtb"
    Terraform = "true"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    # gateway_id     = aws_internet_gateway.internet_gateway.id
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name      = "demo_private_rtb"
    Terraform = "true"
  }
}

#Create route table associations
resource "aws_route_table_association" "public" {
  depends_on     = [aws_subnet.public_subnets]
  route_table_id = aws_route_table.public_route_table.id
  for_each       = aws_subnet.public_subnets
  subnet_id      = each.value.id
}

resource "aws_route_table_association" "private" {
  depends_on     = [aws_subnet.private_subnets]
  route_table_id = aws_route_table.private_route_table.id
  for_each       = aws_subnet.private_subnets
  subnet_id      = each.value.id
}

#Create Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "demo_igw"
  }
}

#Create EIP for NAT Gateway
resource "aws_eip" "nat_gateway_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.internet_gateway]
  tags = {
    Name = "demo_igw_eip"
  }
}

#Create NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
  depends_on    = [aws_subnet.public_subnets]
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnets["public_subnet_1"].id
  tags = {
    Name = "demo_nat_gateway"
  }
}
/* No need to use EC2 at the moment
resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu_16_04.id #Here we use data source to spcify the AMI
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnets["public_subnet_1"].id
  security_groups             = [aws_security_group.vpc-ping.id, aws_security_group.ingress-ssh.id, aws_security_group.vpc-web.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.generated.key_name
  connection {
    user        = "ubuntu"
    private_key = tls_private_key.generated.private_key_pem
    host        = self.public_ip
  }
  #We use that provisioner to change the permissions of the SSH key file. This is executed localy on the workstation where Terraform is installed. Nut it does not work on Windows
  #provisioner "local-exec" {
  #  command = "chmod 600 ${local_file.private_key_pem.filename}"
  #}

  #This will be executed on the EC2 instance. BOTH provisioners should be in the "aws_instance" resource block.
  provisioner "remote-exec" {
    inline = [
      "sudo rm -rf /tmp",
      "sudo git clone https://github.com/hashicorp/demo-terraform-101 /tmp", "sudo sh /tmp/assets/setup-web.sh",
    ]
  }

  tags = local.common_tags
  #tags = {
  # "Terraform" = "true"
  #Name        = local.server_name #This is defined in "locals" block
  #Owner       = lower(local.team)  #We can use "lower" function to make all letters lower and to avoid variable validation if we have it for this local varible
  #App         = local.application
  #"Service"   = local.service_name
  #"AppTeam"   = local.app_team
  #"CreatedBy" = local.createdby
  #}
}
*/

resource "aws_subnet" "variables-subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.variables_sub_cidr
  availability_zone       = var.variables_sub_az
  map_public_ip_on_launch = var.variables_sub_auto_ip
  tags = {
    Name      = "sub-variables-${var.variables_sub_az}"
    Terraform = "true"
  }
}

#Here we generate RSA keys
resource "tls_private_key" "generated" {
  algorithm = "RSA"
}
resource "local_file" "private_key_pem" {
  content  = tls_private_key.generated.private_key_pem
  filename = "MyAWSKey.pem"
}

#SSH key-pair that we generated earlier are going to be used in AWS
resource "aws_key_pair" "generated" {
  key_name   = "MyAWSKey"
  public_key = tls_private_key.generated.public_key_openssh
  lifecycle {
    ignore_changes = [key_name]
  }
}

# Security Groups
resource "aws_security_group" "ingress-ssh" {
  name   = "allow-all-ssh"
  vpc_id = aws_vpc.vpc.id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Security Group - Web Traffic
resource "aws_security_group" "vpc-web" {
  name        = "vpc-web-${terraform.workspace}"
  vpc_id      = aws_vpc.vpc.id
  description = "Web Traffic"
  ingress {
    description = "Allow Port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow Port 443"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow all ip and ports outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "vpc-ping" {
  name        = "vpc-ping"
  vpc_id      = aws_vpc.vpc.id
  description = "ICMP for Ping Access"
  ingress {
    description = "Allow ICMP Traffic"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow all ip and ports outboun"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Lab 61 Dynamic data blocks
resource "aws_security_group" "main" {
  name   = "core-sg-global"
  vpc_id = aws_vpc.vpc.id
  dynamic "ingress" {
    for_each = local.ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  #In lab 63, we have to change the name of the SG and because it is in use , it can not be destroyed and recreated.That is the reason we use lifecycle
  lifecycle {
    create_before_destroy = true
    # prevent destroy = true
  }
}

#Lab 61 Dynamic data blocks - here we use variable in variables.tf
resource "aws_security_group" "main_1" {
  name   = "core-sg_1"
  vpc_id = aws_vpc.vpc.id
  dynamic "ingress" {
    for_each = var.web_ingress
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
}

/*
module "server" {
  source    = "./modules/server"
  ami       = data.aws_ami.ubuntu_16_04.id
  subnet_id = aws_subnet.public_subnets["public_subnet_3"].id
  security_groups = [
    aws_security_group.vpc-ping.id,
    aws_security_group.ingress-ssh.id,
    aws_security_group.vpc-web.id
  ]
}
*/

#This is for Lab 33 - Terraform module sources
/*
module "server_subnet_1" {
  source      = "./modules/web_server"
  ami         = data.aws_ami.ubuntu_16_04.id
  key_name    = aws_key_pair.generated.key_name
  user        = "ubuntu"
  private_key = tls_private_key.generated.private_key_pem
  subnet_id   = aws_subnet.public_subnets["public_subnet_1"].id
  security_groups = [aws_security_group.vpc-ping.id,
    aws_security_group.ingress-ssh.id,
  aws_security_group.vpc-web.id, aws_security_group.main.id]

}
*/
/*Here we use the same module to add second EC2 instance but in another subnet. If we want , we can create another "output" block to see the IP and whatever atribute we want.
module "server_subnet_1" {
  source    = "./modules/server"
  ami       = data.aws_ami.ubuntu_16_04.id
  subnet_id = aws_subnet.public_subnets["public_subnet_1"].id
  security_groups = [
    aws_security_group.vpc-ping.id,
    aws_security_group.ingress-ssh.id,
    aws_security_group.vpc-web.id.
    aws_security_group.main.id
  ]

}

## OUTPUT section. We also have outputs.tf that is the better choice for structuring our configuration.
output "public_ip_server_subnet_1" {
  value = module.server_subnet_1.public_ip
}
output "public_dns_server_subnet_1" {
  value = module.server_subnet_1.public_dns
}

output "public_ip" {
  value = module.server.public_ip
}
output "public_dns" {
  value = module.server.public_dns
}
*/

output "phone_number" {
  value     = var.phone_number
  sensitive = true
}

/*
#The source of this module is Terraform public registry but Git should be installed properly in order to work.
module "autoscaling" {
  source = "github.com/terraform-aws-modules/terraform-aws-autoscaling?ref=v4.9.0"
  # Autoscaling group
  name = "myasg"
  vpc_zone_identifier = [aws_subnet.private_subnets["private_subnet_1"].id
    ,
    aws_subnet.private_subnets["private_subnet_2"].id,
  aws_subnet.private_subnets["private_subnet_3"].id]
  min_size         = 0
  max_size         = 1
  desired_capacity = 1
  # Launch template
  use_lt        = true
  create_lt     = true
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  tags_as_map = {
    Name = "Web EC2 Server 2"
  }
}
*/
# Here we can use var.environment that is set by default to "dev" or enter "prod" or "dev" manually(which is already defined in our variable var.ip in variables.tf) 
/*
resource "aws_subnet" "list_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.ip["prod"]
  availability_zone = var.eu-central-1-azs[0]
}
*/
/*
# Here we use another method that iterates over the values of var.ip
resource "aws_subnet" "list_subnet" {
  for_each          = var.ip
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value #Creates cidr block for each value in var.ip
  availability_zone = var.eu-central-1-azs[0]
  tags = {
    Name = each.key #Creates a tag (prod and dev respectively)
  }
}
*/
#This is improved version of the example above. Here we create the same subnets but in defferent AZs.
resource "aws_subnet" "list_subnet" {
  for_each          = var.env
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value.ip
  availability_zone = each.value.az
  tags = {
    Name = "subnet-${each.value.az}"
  }
}