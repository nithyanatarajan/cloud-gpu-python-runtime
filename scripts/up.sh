#!/bin/bash

STACK_NAME="gpu-remote-kernel"

echo "🔺 Starting resources for stack: $STACK_NAME"

# Get instance ID
INSTANCE_ID=$(aws cloudformation describe-stack-resource \
  --stack-name "$STACK_NAME" \
  --logical-resource-id GPUInstance \
  --query 'StackResourceDetail.PhysicalResourceId' \
  --output text)

echo "✅ Instance ID: $INSTANCE_ID"

# Start EC2 instance
aws ec2 start-instances --instance-ids "$INSTANCE_ID"
echo "🚀 Instance start initiated."

# Wait until running
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
echo "🟢 Instance is running."

# Allocate new Elastic IP
ALLOCATION_ID=$(aws ec2 allocate-address --domain vpc \
  --query 'AllocationId' \
  --output text)

# Associate new Elastic IP
aws ec2 associate-address \
  --instance-id "$INSTANCE_ID" \
  --allocation-id "$ALLOCATION_ID"

# Get public IP for reference
PUBLIC_IP=$(aws ec2 describe-addresses \
  --allocation-ids "$ALLOCATION_ID" \
  --query 'Addresses[0].PublicIp' \
  --output text)

echo "🌐 Elastic IP allocated and associated: $PUBLIC_IP"
echo "☀️ Stack resumed and ready."
