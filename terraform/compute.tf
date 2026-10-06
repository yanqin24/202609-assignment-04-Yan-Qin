resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [
    aws_security_group.app_sg.id
  ]

  subnet_id = data.aws_subnets.default.ids[0]

  tags = {
    Name       = "prompt-optimizer-app"
    AssignedBy = "csye6225-assignment4"
  }
}
