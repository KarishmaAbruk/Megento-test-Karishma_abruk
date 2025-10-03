provider "aws" { region = var.region }

resource "aws_security_group" "magento_sg" {
  name = "magento-sg"
  ingress {
    from_port = 22; to_port = 22; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"]
  }
  ingress { from_port = 80; to_port = 80; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 443; to_port = 443; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_instance" "magento" {
  ami = var.ami
  instance_type = var.instance_type
  key_name = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.magento_sg.id]
  tags = { Name = "magento-debian12" }

  provisioner "remote-exec" {
    inline = [
      "echo 'Instance created.'"
    ]
    connection {
      type = "ssh"
      user = "admin" # adjust for AMI default user (debian/ec2-user/ubuntu)
      private_key = file(var.private_key_path) # or use SSH agent outside Terraform
      host = self.public_ip
    }
  }
}

output "server_public_ip" {
  value = aws_instance.magento.public_ip
}
