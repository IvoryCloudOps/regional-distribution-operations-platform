#!/usr/bin/env python3
"""
Regional Distribution Operations Platform - Health & Resource Audit Script
Description: Inspects ASG target health, ALB status, and RDS availability using Boto3.
Authentication: Uses standard AWS CLI credentials / IAM instance profile (no hardcoded keys).
"""

import boto3
import sys

def audit_platform(region_name="us-east-1"):
    print(f"=== Regional Distribution Operations Platform Audit ({region_name}) ===")
    overall_status = "HEALTHY"
    errors = []

    # 1. EC2 & Auto Scaling Group
    asg_client = boto3.client("autoscaling", region_name=region_name)
    try:
        asg_resp = asg_client.describe_auto_scaling_groups(AutoScalingGroupNames=["distribution-app-asg"])
        if asg_resp["AutoScalingGroups"]:
            asg = asg_resp["AutoScalingGroups"][0]
            print(f"\n[ASG] Name: {asg['AutoScalingGroupName']}")
            print(f"      Instances: {len(asg['Instances'])} (Desired: {asg['DesiredCapacity']}, Min: {asg['MinSize']}, Max: {asg['MaxSize']})")
            for inst in asg["Instances"]:
                print(f"      - InstanceId: {inst['InstanceId']} | Health: {inst['HealthStatus']} | AZ: {inst['AvailabilityZone']}")
                if inst['HealthStatus'] != "Healthy":
                    overall_status = "WARNING"
        else:
            print("\n[ASG] WARNING: 'distribution-app-asg' not found.")
            overall_status = "WARNING"
    except Exception as e:
        print(f"\n[ASG] ERROR querying ASG: {e}")
        overall_status = "FAILED"
        errors.append(f"ASG Query Failed: {e}")

    # 2. Target Group Health
    elbv2_client = boto3.client("elbv2", region_name=region_name)
    try:
        tg_resp = elbv2_client.describe_target_groups(Names=["distribution-app-tg"])
        if tg_resp["TargetGroups"]:
            tg_arn = tg_resp["TargetGroups"][0]["TargetGroupArn"]
            health_resp = elbv2_client.describe_target_health(TargetGroupArn=tg_arn)
            print("\n[ALB Target Group Health]")
            for target in health_resp["TargetHealthDescriptions"]:
                target_id = target["Target"]["Id"]
                port = target["Target"]["Port"]
                state = target["TargetHealth"]["State"]
                print(f"      - Target: {target_id}:{port} => Status: {state}")
                if state != "healthy":
                    overall_status = "WARNING"
        else:
            print("\n[ALB] WARNING: 'distribution-app-tg' not found.")
            overall_status = "WARNING"
    except Exception as e:
        print(f"\n[ALB] ERROR querying Target Group: {e}")
        overall_status = "FAILED"
        errors.append(f"ALB Target Group Query Failed: {e}")

    # 3. RDS Database Status
    rds_client = boto3.client("rds", region_name=region_name)
    try:
        rds_resp = rds_client.describe_db_instances(DBInstanceIdentifier="distribution-mysql")
        if rds_resp["DBInstances"]:
            db = rds_resp["DBInstances"][0]
            print("\n[RDS Database]")
            print(f"      - Identifier: {db['DBInstanceIdentifier']}")
            print(f"      - Engine: {db['Engine']} {db['EngineVersion']}")
            print(f"      - Status: {db['DBInstanceStatus']}")
            print(f"      - Multi-AZ: {db['MultiAZ']}")
            print(f"      - Endpoint: {db.get('Endpoint', {}).get('Address', 'N/A')}")
            if db['DBInstanceStatus'] != "available":
                overall_status = "WARNING"
        else:
            print("\n[RDS] WARNING: 'distribution-mysql' not found.")
            overall_status = "WARNING"
    except Exception as e:
        print(f"\n[RDS] ERROR querying RDS: {e}")
        overall_status = "FAILED"
        errors.append(f"RDS Query Failed: {e}")

    print("\n------------------------------------------------------------")
    if overall_status == "HEALTHY":
        print(">>> Platform Audit Status: HEALTHY (All services operational)")
        return 0
    elif overall_status == "WARNING":
        print(">>> Platform Audit Status: WARNING (Degraded components detected)")
        return 1
    else:
        print(f">>> Platform Audit Status: FAILED ({len(errors)} error(s) encountered)")
        for err in errors:
            print(f"    - {err}")
        return 2

if __name__ == "__main__":
    region = sys.argv[1] if len(sys.argv) > 1 else "us-east-1"
    exit_code = audit_platform(region)
    sys.exit(exit_code)
