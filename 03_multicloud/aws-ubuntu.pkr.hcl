packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }

    azure = {
      version = ">= 2.0.0"
      source  = "github.com/hashicorp/azure"
    }
  }
}

# ==========================
# AWS
# ==========================

source "amazon-ebs" "ubuntu" {
  ami_name      = "node-nginx-{{timestamp}}"
  instance_type = "t3.micro"
  region        = "us-west-2"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }

    most_recent = true
    owners      = ["099720109477"]
  }

  ssh_username = "ubuntu"
}

# ==========================
# Azure
# ==========================

source "azure-arm" "ubuntu" {
  use_azure_cli_auth = true

  subscription_id = "a452fff0-1433-47fa-b372-cd76c8bece23"

  image_offer     = "0001-com-ubuntu-server-jammy"
  image_publisher = "canonical"
  image_sku       = "22_04-lts"

  location = "centralus"
  vm_size  = "Standard_D2s_v3"

  managed_image_name                = "node-nginx-image"
  managed_image_resource_group_name = "packer-rg"

  os_type = "Linux"

  ssh_username = "azureuser"
}

# ==========================
# Build
# ==========================

build {
  name = "node-nginx"

  sources = [
    "source.amazon-ebs.ubuntu",
    "source.azure-arm.ubuntu"
  ]

  provisioner "file" {
    source      = "app.js"
    destination = "/tmp/app.js"
  }

  provisioner "file" {
    source      = "default.nginx"
    destination = "/tmp/default.nginx"
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get update",

      "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -",

      "sudo apt-get install -y nodejs nginx",

      "sudo npm install -g pm2",

      "mkdir -p $HOME/app",

      "mv /tmp/app.js $HOME/app/app.js",

      "sudo mv /tmp/default.nginx /etc/nginx/sites-available/default",

      "sudo systemctl enable nginx",
      "sudo systemctl restart nginx",

      "cd $HOME/app && pm2 start app.js --name app",

      "pm2 save",

      "sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u $(whoami) --hp $HOME"
    ]
  }
}