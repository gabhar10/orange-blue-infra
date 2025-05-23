#!/usr/bin/env python3
"""
Infrastructure Test Script
Tests that blue can SSH to orange but not vice versa.

Tested with:
- boto3==1.38.23
- botocore==1.38.23
- Python 3.11+

Dependencies are pinned in requirements.txt to avoid version conflicts.
"""

import boto3
import time
import sys
import os
from botocore.exceptions import ClientError

def get_aws_region():
    """Get AWS region from environment or default."""
    region = os.environ.get('AWS_DEFAULT_REGION') or os.environ.get('AWS_REGION')
    if not region:
        region = 'us-east-1'  # Default fallback
        print(f"WARNING: No AWS region specified, using default: {region}")
    else:
        print(f"Using AWS region: {region}")
    return region

def get_instances():
    """Get blue and orange instance details."""
    region = get_aws_region()
    ec2 = boto3.client('ec2', region_name=region)
    
    try:
        response = ec2.describe_instances(
            Filters=[
                {'Name': 'tag:Name', 'Values': ['blue', 'orange']},
                {'Name': 'instance-state-name', 'Values': ['running']}
            ]
        )
        
        instances = {}
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                name = next((tag['Value'] for tag in instance['Tags'] if tag['Key'] == 'Name'), None)
                if name:
                    # Map the full names to simple names for easier reference
                    simple_name = 'blue' if 'blue' in name.lower() else 'orange' if 'orange' in name.lower() else name
                    instances[simple_name] = {
                        'instance_id': instance['InstanceId'],
                        'private_ip': instance['PrivateIpAddress'],
                        'full_name': name
                    }
        
        if len(instances) != 2:
            print(f"ERROR: Expected 2 instances, found {len(instances)}: {list(instances.keys())}")
            return None
            
        print(f"SUCCESS: Found instances: {[inst['full_name'] for inst in instances.values()]}")
        return instances
        
    except ClientError as e:
        print(f"ERROR: Error getting instances: {e}")
        return None

def execute_ssm_command(instance_id, command, timeout=30):
    """Execute a command on an instance via SSM."""
    region = get_aws_region()
    ssm = boto3.client('ssm', region_name=region)
    
    try:
        response = ssm.send_command(
            InstanceIds=[instance_id],
            DocumentName='AWS-RunShellScript',
            Parameters={'commands': [command]},
            TimeoutSeconds=timeout
        )
        
        command_id = response['Command']['CommandId']
        
        max_attempts = timeout // 2
        for attempt in range(max_attempts):
            try:
                result = ssm.get_command_invocation(
                    CommandId=command_id,
                    InstanceId=instance_id
                )
                
                status = result['Status']
                if status in ['Success', 'Failed']:
                    return {
                        'success': status == 'Success',
                        'stdout': result.get('StandardOutputContent', ''),
                        'stderr': result.get('StandardErrorContent', ''),
                        'exit_code': result.get('ResponseCode', -1)
                    }
                    
            except ClientError as e:
                if 'InvocationDoesNotExist' not in str(e):
                    print(f"WARNING: Error checking command status: {e}")
            
            time.sleep(2)
        
        return {'success': False, 'stdout': '', 'stderr': 'Command timeout', 'exit_code': -1}
        
    except ClientError as e:
        return {'success': False, 'stdout': '', 'stderr': f'SSM Error: {e}', 'exit_code': -1}

def test_connectivity():
    """Test the infrastructure connectivity requirements."""
    print("Starting infrastructure tests...")
    
    instances = get_instances()
    if not instances:
        sys.exit(1)
    
    blue_id = instances['blue']['instance_id']
    orange_id = instances['orange']['instance_id']
    orange_ip = instances['orange']['private_ip']
    blue_ip = instances['blue']['private_ip']
    
    print(f"\nTest Configuration:")
    print(f"   Blue: {blue_id} ({blue_ip})")
    print(f"   Orange: {orange_id} ({orange_ip})")
    
    tests_passed = 0
    total_tests = 2

    # Test 1: Blue can reach orange via SSH
    print(f"\nTest 1: Blue can SSH to Orange ({orange_ip})")

    ssh_cmd = f"timeout 10 ssh -i /home/ssm-user/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@{orange_ip} 'echo SSH_SUCCESS'"
    result = execute_ssm_command(blue_id, ssh_cmd)
    
    if result['success'] and 'SSH_SUCCESS' in result['stdout']:
        print("   PASS: Blue can SSH to Orange")
        tests_passed += 1
    else:
        print("   FAIL: Blue cannot SSH to Orange")
        print(f"      Exit code: {result['exit_code']}")
        print(f"      Stdout: {result['stdout'][:200]}")
        print(f"      Stderr: {result['stderr'][:200]}")
    
    # Test 2: Orange cannot SSH to blue
    print(f"\nTest 2: Orange cannot SSH to Blue ({blue_ip})")
    ssh_cmd = f"HOME=/home/ssm-user timeout 10 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@{blue_ip} 'echo SSH_SUCCESS'"
    result = execute_ssm_command(orange_id, ssh_cmd)
    
    # This should fail - orange shouldn't be able to SSH to blue
    if not result['success'] or 'SSH_SUCCESS' not in result['stdout']:
        print("   PASS: Orange correctly cannot SSH to Blue")
        tests_passed += 1
    else:
        print("   FAIL: Orange can SSH to Blue (this should not be possible)")
        print(f"      Stdout: {result['stdout'][:200]}")
    
    # Summary
    print(f"\nTest Results: {tests_passed}/{total_tests} tests passed")
    
    if tests_passed == total_tests:
        print("SUCCESS: ALL TESTS PASSED! Infrastructure is working correctly.")
        return True
    else:
        print("ERROR: SOME TESTS FAILED! Check the infrastructure configuration.")
        return False

if __name__ == "__main__":
    success = test_connectivity()
    sys.exit(0 if success else 1)