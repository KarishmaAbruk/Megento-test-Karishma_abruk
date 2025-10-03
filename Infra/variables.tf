variable "region" { type = string, default = "us-east-1" }
variable "instance_type" { type = string, default = "t3.medium" }
variable "ami" { type = string, description = "Debian 12 AMI id (set per-region)" }
variable "ssh_key_name" { type = string, description = "Name of AWS keypair" }
