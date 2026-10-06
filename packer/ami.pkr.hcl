# CSYE 6225 - Assignment 4
# YOUR WORK: Complete this file (or split it into multiple .pkr.hcl files
# in this directory if you prefer - Packer loads every .pkr.hcl file here).
#
# Requirements:
#
# 1. required_plugins block: this template requires the "amazon" plugin
#    (source = "github.com/hashicorp/amazon", version >= 1.0.0).
#
# 2. A `source "amazon-ebs" "app"` block that:
#    - Builds in us-west-2
#    - Uses instance_type "t2.micro" or "t3.micro" for the BUILD (this is
#      not the same variable as your Terraform instance_type - Packer
#      only uses this instance temporarily to build the image)
#    - Uses ssh_username "ubuntu"
#    - Looks up the source AMI with a source_ami_filter matching
#      Ubuntu 22.04 LTS amd64, owned by Canonical (owner ID 099720109477)
#      - most_recent = true
#    - Sets an ami_name (must be unique per build - use a timestamp,
#      e.g. "prompt-optimizer-{{timestamp}}")
#
# 3. A `build` block that:
#    - References your source block
#    - Uses a "file" provisioner to copy the ../app directory to
#      /tmp/app on the build instance
#    - Uses a "shell" provisioner to run ../app/install_app.sh
#      (install_app.sh is provided complete - you should not need to
#      modify it)
#
# Refer to the Module 4 slides for the block syntax (source, build,
# provisioner "file", provisioner "shell").
