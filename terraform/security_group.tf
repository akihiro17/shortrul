resource "aws_security_group" "api" {
  name   = "api"
  vpc_id = aws_vpc.main.id
}

resource "aws_vpc_security_group_egress_rule" "api" {
  security_group_id = aws_security_group.api.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

resource "aws_security_group" "rds" {
  name   = "rds"
  vpc_id = aws_vpc.main.id
}

resource "aws_vpc_security_group_egress_rule" "rds" {
  security_group_id = aws_security_group.rds.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

resource "aws_security_group" "migration_instance" {
  name   = "migration_instance"
  vpc_id = aws_vpc.main.id
}

resource "aws_vpc_security_group_egress_rule" "migration_instance" {
  security_group_id = aws_security_group.migration_instance.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}


resource "aws_vpc_security_group_ingress_rule" "rds_access_from_api" {
  security_group_id = aws_security_group.rds.id

  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.api.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_access_from_migration_instance" {
  security_group_id = aws_security_group.rds.id

  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.migration_instance.id
}

resource "aws_vpc_security_group_ingress_rule" "api_access_from_alb" {
  security_group_id = aws_security_group.api.id

  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb_security_group.id
}

resource "aws_vpc_security_group_ingress_rule" "instance_for_migration_via_ssh" {
  security_group_id = aws_security_group.migration_instance.id

  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

# alb -> (security group) -> api
resource "aws_security_group" "alb_security_group" {
  name        = "alb-sg"
  description = "ALB Secuirty Group"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_inbound" {
  security_group_id = aws_security_group.alb_security_group.id

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "allow_http_inbound" {
  security_group_id = aws_security_group.alb_security_group.id

  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.api.id
}
