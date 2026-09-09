#--------------------------------
# Dynamic Scaling Policy (Target Tracking)
#--------------------------------

resource "aws_autoscaling_policy" "asg_target_tracking_cpu" {
  name                   = "distribution-asg-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.distribution_app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60.0
  }
}

# Scheduled Scaling: Business Hours Scale-Up

resource "aws_autoscaling_schedule" "scale_out_business_hours" {
  scheduled_action_name  = "scale-out-business-hours"
  min_size               = 2
  max_size               = 6
  desired_capacity       = 4
  time_zone              = "America/New_York"
  recurrence             = "0 7 * * 1-5"
  autoscaling_group_name = aws_autoscaling_group.distribution_app.name
}

# Scheduled Scaling: Off-Hours Scale-Down

resource "aws_autoscaling_schedule" "scale_in_off_hours" {
  scheduled_action_name  = "scale-in-off-hours"
  min_size               = 2
  max_size               = 6
  desired_capacity       = 2
  time_zone              = "America/New_York"
  recurrence             = "30 18 * * 1-5"
  autoscaling_group_name = aws_autoscaling_group.distribution_app.name
}
