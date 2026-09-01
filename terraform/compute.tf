data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_launch_template" "distribution_app" {
  name_prefix            = "distribution-app-"
  image_id               = "ami-0fe74bfcad4fd6bd2"
  instance_type          = "t3.micro"
  update_default_version = true
  user_data              = base64encode(file("${path.module}/scripts/app_user_data.sh"))


  iam_instance_profile {
    name = aws_iam_instance_profile.distribution_ec2_instance_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.distribution_app_sg.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "distribution-app"
      environment = "development"
      managed_by  = "Terraform"
    }
  }
}

resource "aws_autoscaling_group" "distribution_app" {
  name                      = "distribution-app-asg"
  min_size                  = 2
  desired_capacity          = 2
  max_size                  = 6
  vpc_zone_identifier       = [aws_subnet.distribution_private_app_a.id, aws_subnet.distribution_private_app_b.id]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.distribution_app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "distribution-app"
    propagate_at_launch = true
  }

  tag {
    key                 = "environment"
    value               = "development"
    propagate_at_launch = true
  }

  tag {
    key                 = "managed_by"
    value               = "Terraform"
    propagate_at_launch = true
  }
}
