locals {
  blue_user_data = base64encode(
    templatefile("${path.module}/scripts/blue-userdata.sh", {
      AWS_REGION = var.aws_region
    })
  )
  
  orange_user_data = base64encode(
    templatefile("${path.module}/scripts/orange-userdata.sh", {
      AWS_REGION = var.aws_region
    })
  )
}

# Create EC2 instances
resource "aws_instance" "hosts" {
  for_each             = var.aws_ec2_instances
  ami                  = var.aws_ami
  instance_type        = each.value.type
  subnet_id            = aws_subnet.private.id
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [
    each.key == "blue" ? aws_security_group.blue.id : aws_security_group.orange.id
  ]
  associate_public_ip_address = false

  # Enable metadata (IMDSv2) service
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Add user data based on instance type
  user_data = each.key == "blue" ? local.blue_user_data : local.orange_user_data

  depends_on = [
    aws_vpc_endpoint.ssm,
    aws_vpc_endpoint.ssmmessages,
    aws_vpc_endpoint.ec2messages,
    aws_vpc_endpoint.s3,
    aws_ssm_parameter.ssh_key
  ]

  tags = {
    Name = each.value.name
  }
}

# Security groups
resource "aws_security_group" "blue" {
  name        = "blue-instance-sg"
  description = "Security group for blue instance - can SSH to orange"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "blue-instance-sg"
  }
}

resource "aws_security_group" "orange" {
  name        = "orange-instance-sg"
  description = "Security group for orange instance - accepts SSH from blue"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "orange-instance-sg"
  }
}

# Security group rules
resource "aws_security_group_rule" "blue_ssh_to_orange" {
  type                     = "egress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.orange.id
  security_group_id        = aws_security_group.blue.id
}

resource "aws_security_group_rule" "blue_https_to_vpc_endpoints" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vpc_endpoints.id
  security_group_id        = aws_security_group.blue.id
}

resource "aws_security_group_rule" "orange_ssh_from_blue" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.blue.id
  security_group_id        = aws_security_group.orange.id
}

resource "aws_security_group_rule" "orange_https_to_vpc_endpoints" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vpc_endpoints.id
  security_group_id        = aws_security_group.orange.id
}