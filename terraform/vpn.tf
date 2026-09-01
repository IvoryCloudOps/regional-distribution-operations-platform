#-------------------------
# Client VPN Security Group
#-------------------------

resource "aws_security_group" "distribution_vpn_sg" {
  name        = "distribution-vpn-sg"
  description = "Security group for AWS Client VPN"
  vpc_id      = aws_vpc.distribution_vpc.id

  tags = {
    Name        = "distribution-vpn-sg"
    environment = "development"
    managed_by  = "Terraform"
  }
}

resource "aws_vpc_security_group_egress_rule" "vpn_egress" {
  security_group_id = aws_security_group.distribution_vpn_sg.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

#-------------------------
# Client VPN Endpoint
#-------------------------

resource "aws_ec2_client_vpn_endpoint" "distribution_vpn" {
  description            = "Regional Distribution Operations Client VPN"
  server_certificate_arn = "arn:aws:acm:us-east-1:075723833258:certificate/02eb3b88-38c0-49fd-9344-09422d20e491"
  client_cidr_block      = "172.16.0.0/22"
  split_tunnel           = true

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = "arn:aws:acm:us-east-1:075723833258:certificate/2d35c54d-7411-47af-b800-d5182861fda8"
  }

  connection_log_options {
    enabled = false
  }

  security_group_ids = [
    aws_security_group.distribution_vpn_sg.id
  ]

  vpc_id = aws_vpc.distribution_vpc.id

  tags = {
    Name        = "distribution-client-vpn"
    environment = "development"
    managed_by  = "Terraform"
  }
}

resource "aws_ec2_client_vpn_network_association" "distribution_vpn_association" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.distribution_vpn.id
  subnet_id              = aws_subnet.distribution_private_app_a.id
}

resource "aws_ec2_client_vpn_network_association" "distribution_vpn_association_b" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.distribution_vpn.id
  subnet_id              = aws_subnet.distribution_private_app_b.id
}


resource "aws_ec2_client_vpn_authorization_rule" "distribution_vpn_auth_rule" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.distribution_vpn.id
  target_network_cidr    = "10.0.0.0/16"
  authorize_all_groups   = true
}