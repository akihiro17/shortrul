variable "key_name" {}

resource "aws_db_subnet_group" "default" {
  name = "main"
  subnet_ids = [
    aws_subnet.private["ap-northeast-1a"].id,
    aws_subnet.private["ap-northeast-1c"].id,
  ]
}

resource "aws_rds_cluster" "test" {
  cluster_identifier      = "rds-cluster"
  engine                  = "aurora-mysql"
  engine_mode             = "provisioned"
  engine_version          = "8.0.mysql_aurora.3.04.0"
  master_username         = "root"
  master_password         = "password"
  backup_retention_period = 1
  skip_final_snapshot     = true
  vpc_security_group_ids  = [aws_security_group.rds.id]
  db_subnet_group_name    = aws_db_subnet_group.default.name
}

resource "aws_rds_cluster_instance" "instances" {
  engine             = "aurora-mysql"
  engine_version     = "8.0.mysql_aurora.3.04.0"
  identifier         = "${aws_rds_cluster.test.cluster_identifier}-1"
  cluster_identifier = aws_rds_cluster.test.id
  instance_class     = "db.t3.medium"
}

data "aws_ami" "amazon_linux2" {
  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.20230119.1-x86_64-ebs"]
  }
}

resource "aws_instance" "migration_instance" {
  ami           = data.aws_ami.amazon_linux2.id
  instance_type = "t3.nano"
  key_name      = var.key_name

  subnet_id              = aws_subnet.public["ap-northeast-1a"].id
  vpc_security_group_ids = [aws_security_group.migration_instance.id]

  associate_public_ip_address = true

  user_data = <<EOF
#!/bin/bash
rpm -Uvh https://dev.mysql.com/get/mysql80-community-release-el7-1.noarch.rpm
sudo rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2022
yum install -y mysql-community-client
EOF
}

output "migration_instance_public_ip" {
  value = aws_instance.migration_instance.public_ip
}

output "rds_endpoint" {
  value = aws_rds_cluster.test.endpoint
}

output "rds_reader_endpoint" {
  value = aws_rds_cluster.test.reader_endpoint
}
