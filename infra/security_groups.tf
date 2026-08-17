# Attached to the Lambda function. No inbound rules at all - API Gateway
# invokes Lambda through the Lambda API, not through the VPC network, so
# nothing ever needs to initiate a connection *into* Lambda over the VPC.
resource "aws_security_group" "lambda" {
  name_prefix = "${var.project_name}-lambda-"
  description = "Lambda function - egress to RDS only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-lambda-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Attached to the RDS instance. No inbound rules by default here either -
# the actual allow-rule is defined below as a separate resource that
# references both SGs, avoiding a circular inline reference between them.
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  description = "RDS Postgres - ingress from Lambda only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-rds-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Lambda -> RDS on 5432, and nothing else outbound from Lambda.
resource "aws_vpc_security_group_egress_rule" "lambda_to_rds" {
  security_group_id            = aws_security_group.lambda.id
  referenced_security_group_id = aws_security_group.rds.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "To RDS Postgres"
}

# RDS accepts 5432 only from things wearing the Lambda SG - not from any
# IP range, from the security group itself.
resource "aws_vpc_security_group_ingress_rule" "rds_from_lambda" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.lambda.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "From Lambda"
}
