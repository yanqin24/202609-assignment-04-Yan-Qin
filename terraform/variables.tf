# CSYE 6225 - Assignment 4
# YOUR WORK: Complete this file.
#
# Define the input variables your compute.tf will need. At minimum you
# will need variables for:
#   - The AMI ID produced by your Packer build (no default - you must
#     supply this value in terraform.tfvars)
#   - The instance type (must be t2.micro or t3.micro - give it a sensible
#     default so `terraform apply` works without extra flags)
#   - The EC2 key pair name to use for SSH access (no default - supply
#     your own key pair name in terraform.tfvars)
#
# Example structure (fill in the details):
#
# variable "ami_id" {
#   description = "..."
#   type        = string
# }
