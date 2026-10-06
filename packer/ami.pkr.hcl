packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.0.0"
    }
  }
}

source "amazon-ebs" "app" {
  region        = "us-west-2"
  instance_type = "t2.micro"
  ssh_username  = "ubuntu"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }

    owners      = ["099720109477"]
    most_recent = true
  }

  ami_name = "prompt-optimizer-{{timestamp}}"
}

build {
  sources = ["source.amazon-ebs.app"]

  provisioner "file" {
    source      = "../app"
    destination = "/tmp/app"
  }

  provisioner "shell" {
    script = "../app/install_app.sh"
  }
}
