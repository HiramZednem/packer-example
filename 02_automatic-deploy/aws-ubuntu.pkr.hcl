packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

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

build {
  name = "node-nginx"

  sources = [
    "source.amazon-ebs.ubuntu"
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

        "mkdir -p /home/ubuntu/app",

        "mv /tmp/app.js /home/ubuntu/app/app.js",

        "sudo mv /tmp/default.nginx /etc/nginx/sites-available/default",

        "sudo systemctl enable nginx",
        "sudo systemctl restart nginx",

        "cd /home/ubuntu/app && pm2 start app.js --name app",

        "pm2 save",

        "sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu"
      ]
    }

  post-processor "manifest" {
    output = "manifest.json"
  }

  post-processor "shell-local" {
    inline = [
      "AMI_ID=$(jq -r '.builds[-1].artifact_id' manifest.json | cut -d':' -f2)",
      "aws ec2 run-instances --image-id $AMI_ID --instance-type t3.micro --security-group-ids sg-07028a5e5b6540e6e --region us-west-2"
    ]
  }
}