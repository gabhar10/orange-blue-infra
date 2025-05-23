variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_vpc_name" {
  type        = string
  default     = "takehome-vpc"
  description = "Name of VPC to create"
}

variable "aws_vpc_cidr_block" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block for VPC"
}

variable "aws_vpc_private_subnet_cidr_block" {
  type        = string
  default     = "10.0.1.0/24"
  description = "CIDR block for private subnet"
}

variable "aws_ec2_instances" {
  type = map(object({
    name = string
    type = string
  }))
  default = {
    "blue" = {
      name = "blue"
      type = "t2.micro"
    },
    "orange" = {
      name = "orange"
      type = "t2.micro"
    }
  }
}

variable "aws_ami" {
  type    = string
  default = "ami-055c4ffce961ad000"
}