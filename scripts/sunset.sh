#!/bin/bash
  STACK_NAME="gpu-remote-kernel"

echo "🔻 Stopping resources for stack: $STACK_NAME"

# Get instance ID
INSTANCE_ID=$(aws cloudformation describe-stack-resource \
  --stack-name "$STACK_NAME" \
  --logical-resource-id GPUInstance \
  --query 'StackResourceDetail.PhysicalResourceId' \
  --output text)

echo "✅ Instance ID: $INSTANCE_ID"

# Stop EC2 instance
aws ec2 stop-instances --instance-ids "$INSTANCE_ID"
echo "🛑 Instance stopping initiated."

# Get Elastic IP allocation and association IDs
ALLOCATION_ID=$(aws ec2 describe-addresses \
  --filters "Name=instance-id,Values=$INSTANCE_ID" \
  --query "Addresses[0].AllocationId" \
  --output text || true)

ASSOCIATION_ID=$(aws ec2 describe-addresses \
  --filters "Name=instance-id,Values=$INSTANCE_ID" \
  --query "Addresses[0].AssociationId" \
  --output text || true)

if [[ -n "$ASSOCIATION_ID" ]]; then
  aws ec2 disassociate-address --association-id "$ASSOCIATION_ID"
  echo "🔌 Elastic IP disassociated."
fi

if [[ -n "$ALLOCATION_ID" ]]; then
  aws ec2 release-address --allocation-id "$ALLOCATION_ID"
  echo "♻️ Elastic IP released."
fi

echo "🌙 Sunset complete."
