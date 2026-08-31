
#-----------------------
# 3 tier Security Groups
#------------------------

# Security group for ALB
resource "aws_security_group" "distribution_alb_sg" {
  name        = "distribution-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.distribution_vpc.id

  tags = {
    Name        = "distribution-alb-sg"
    environment = "Learning"
    managed_by  = "Terraform"
  }
}

# Security group for Application Server
resource "aws_security_group" "distribution_app_sg" {
  name        = "distribution-app-sg"
  description = "Security group for Application Server"
  vpc_id      = aws_vpc.distribution_vpc.id

  tags = {
    Name        = "distribution-app-sg"
    environment = "Learning"
    managed_by  = "Terraform"
  }
}

# Security group for Database Server
resource "aws_security_group" "distribution_db_sg" {
  name        = "distribution-db-sg"
  description = "Security group for Database Server"
  vpc_id      = aws_vpc.distribution_vpc.id

  tags = {
    Name        = "distribution-db-sg"
    environment = "Learning"
    managed_by  = "Terraform"
  }
}


#-----------------------------------
# Ingress Rules for Security Groups
#-----------------------------------

# app_from_alb Ingress Rule
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id = aws_security_group.distribution_app_sg.id

  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.distribution_alb_sg.id
}

# db_from_app Ingress Rule
resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id = aws_security_group.distribution_db_sg.id

  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.distribution_app_sg.id
}

#--------------
# Egress Rules
#--------------

# ALB Egress Rules
resource "aws_vpc_security_group_egress_rule" "alb_egress" {
  security_group_id = aws_security_group.distribution_alb_sg.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

# App Egress Rules
resource "aws_vpc_security_group_egress_rule" "app_egress" {
  security_group_id = aws_security_group.distribution_app_sg.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}


#--------------------
# IAM/EC2 Management
#--------------------

# IAM Role for EC2 Instance
resource "aws_iam_role" "distribution_ec2_role" {
  name = "distribution_ec2_instance_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Instance Profile for EC2 Instance
resource "aws_iam_instance_profile" "distribution_ec2_instance_profile" {
  name = "distribution_ec2_instance_profile"
  role = aws_iam_role.distribution_ec2_role.name
}

# IAM Role Policy Attachment for SSM
resource "aws_iam_role_policy_attachment" "distribution_ssm_role_attachment" {
  role       = aws_iam_role.distribution_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


