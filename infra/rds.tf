# Tells RDS which subnets it may place its network interface in - the
# resource that actually consumes the two private subnets from vpc.tf.
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# Generated once, stored in Terraform state (gitignored, plaintext there -
# fine for solo/local state, would need a remote encrypted backend for a
# real team). Fed straight into the Lambda's environment in lambda.tf later.
resource "random_password" "db" {
  length  = 32
  special = false # keep it URL-safe; it goes straight into a DATABASE_URL connection string
}

resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-db"
  engine         = "postgres"
  engine_version = "16.14"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period = 0
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = {
    Name = "${var.project_name}-db"
  }
}
