# Create SSM parameter for SSH key sharing
resource "aws_ssm_parameter" "ssh_key" {
  name  = "/ssh/blue-to-orange/public_key"
  type  = "String"
  value = "UNINITIALIZED"

  lifecycle {
    ignore_changes = [value] # Allow blue instance to update it
  }

  tags = {
    Name = "blue-to-orange-ssh-key"
  }
}