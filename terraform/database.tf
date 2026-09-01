#-------------------------
# RDS DB Subnet Group
#-------------------------

resource "aws_db_subnet_group" "distribution_db_subnet_group" {
  name = "distribution-db-subnet-group"

  subnet_ids = [
    aws_subnet.distribution_private_db_a.id,
    aws_subnet.distribution_private_db_b.id
  ]

  tags = {
    Name        = "distribution-db-subnet-group"
    environment = "development"
    managed_by  = "Terraform"
  }
}

#-------------------------
# MySQL RDS Database
#-------------------------

resource "aws_db_instance" "distribution_mysql" {
  identifier = "distribution-mysql"

  engine         = "mysql"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "distributiondb"
  username = "distribution_admin"

  # AWS automatically manages the master password in Secrets Manager
  manage_master_user_password = true

  db_subnet_group_name = aws_db_subnet_group.distribution_db_subnet_group.name

  vpc_security_group_ids = [
    aws_security_group.distribution_db_sg.id
  ]

  publicly_accessible = false
  multi_az            = true

  backup_retention_period = 7

  # Development/lab settings
  deletion_protection = false
  skip_final_snapshot = true

  tags = {
    Name        = "distribution-mysql"
    environment = "development"
    managed_by  = "Terraform"
  }
}