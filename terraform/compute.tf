# CSYE 6225 - Assignment 4
# YOUR WORK: Complete this file.
#
# Define the aws_instance resource that deploys your Packer-built AMI.
# Requirements (see the assignment instructions for full detail):
#
#   - Use var.ami_id as the AMI (your custom Packer-built image, not a
#     stock Ubuntu image)
#   - Use var.instance_type
#   - Use var.key_name for the key pair
#   - Attach the security group defined in network.tf
#     (aws_security_group.app_sg.id)
#   - Launch into one of the default subnets
#     (data.aws_subnets.default.ids[0])
#   - Tag the instance with, at minimum:
#       Name       = "prompt-optimizer-app"
#       AssignedBy = "csye6225-assignment4"
#     (the autograder checks for these exact tag values)
#
# Example structure (fill in the details):
#
# resource "aws_instance" "app" {
#   ami                    = var.ami_id
#   instance_type          = var.instance_type
#   ...
# }
