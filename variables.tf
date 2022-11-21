variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "vpc_name" {
  type    = string
  default = "demo_vpc"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "private_subnets" {
  default = {
    "private_subnet_1" = 0
    "private_subnet_2" = 1
    "private_subnet_3" = 2
  }
}

variable "public_subnets" {
  default = {
    "public_subnet_1" = 0
    "public_subnet_2" = 1
    "public_subnet_3" = 2
  }
}

variable "variables_sub_cidr" {
  description = "CIDR Block for the Variables Subnet"
  type        = string
  default     = "10.0.250.0/24"
}
variable "variables_sub_az" {
  description = "Availability Zone used Variables Subnet"
  type        = string
  default     = "eu-central-1a"
}
variable "variables_sub_auto_ip" {
  description = "Set Automatic IP Assigment for Variables Subnet"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Dev or Prod"
  type        = string
  default     = "dev"
}

variable "eu-central-1-azs" {
  type = list(string)
  default = [
    "eu-central-1a",
    "eu-central-1b",
    "eu-central-1c",

  ]
}

variable "ip" {
  type = map(string)
  default = {
    prod = "10.0.150.0/24"
    dev  = "10.0.251.0/24"
  }
}

#We should this way if we want better structure and subnets deployed in different AZs. We create "map of maps".
variable "env" {
  type = map(any)
  default = {
    prod = {
      ip = "10.0.150.0/24"
      az = "eu-central-1a"
    }
    dev = {
      ip = "10.0.251.0/24"
      az = "eu-central-1b"
    }
  }
}

#LAB 60 Built-In functions
variable "num_1" {
  type        = number
  description = "Numbers for function labs"
  default     = 88
}
variable "num_2" {
  type        = number
  description = "Numbers for function labs"
  default     = 73
}
variable "num_3" {
  type        = number
  description = "Numbers for function labs"
  default     = 52
}

#Lab61 Dynamic blocks
variable "web_ingress" {
  type = map(object(
    {
      description = string
      port        = number
      protocol    = string
      cidr_blocks = list(string)
    }
  ))
  default = {
    "80" = {
      description = "Port 80"
      port        = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
    "443" = {
      description = "Port 443"
      port        = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}