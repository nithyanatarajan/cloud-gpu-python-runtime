# Remote GPU Kernel Setup with Prebaked AMI

This document provides a **step-by-step guide** for setting up a remote kernel in GPU-enabled EC2 instance using AWS CloudFormation from existing AMI. 
The setup allows you to run GPU-accelerated tasks on a remote instance.

---

## 📦 Prerequisites

- AWS account with proper permissions (CloudFormation, EC2, Image Builder, IAM, SSM)
- AWS CLI installed and configured (`aws configure`)
- An existing SSH KeyPair in AWS (or create one beforehand)
- A public IP address to restrict SSH access (optional but recommended)

---

## Creating a Pre-baked AMI from an existing GPU instance

### One-Time: Create AMI from EC2 Instance

This document assumes you have an existing EC2 instance with GPU support that has been configured with the necessary software and settings.
For configuring this instance, you can refer to [README.md](../README.md)

```shell
INSTANCE_ID=$(aws cloudformation describe-stack-resources \
  --stack-name gpu-remote-kernel \
  --query "StackResources[?ResourceType=='AWS::EC2::Instance'].PhysicalResourceId" \
  --output text)

AMI_NAME="GPU-configured-vm"

DESCRIPTION="Snapshot of fully configured VM"
```

```shell
# Create AMI and capture AMI ID
AMI_ID=$(aws ec2 create-image \
  --instance-id "$INSTANCE_ID" \
  --name "$AMI_NAME" \
  --description "$DESCRIPTION" \
  --reboot \
  --tag-specifications "ResourceType=image,Tags=[{Key=Purpose,Value=BaseImage}]" \
                       "ResourceType=snapshot,Tags=[{Key=Purpose,Value=BaseImage}]" \
  --query 'ImageId' \
  --output text)

echo "✅ AMI creation initiated: $AMI_ID"
```


### 🔍 Debug: AMI Stuck in Pending

#### Check AMI State

```shell
aws ec2 describe-images --image-ids "$AMI_ID" \
  --query 'Images[0].State'
```

#### Get Snapshot ID(s) Associated with AMI

```shell
aws ec2 describe-images --image-ids "$AMI_ID" \
  --query 'Images[0].BlockDeviceMappings'
```

#### Check Snapshot Status

SNAPSHOT_ID=$(aws ec2 describe-images --image-ids "$AMI_ID" \
  --query "Images[].BlockDeviceMappings[].Ebs.SnapshotId" --output text)

```shell
aws ec2 describe-snapshots --snapshot-ids $SNAPSHOT_ID \
  --query 'Snapshots[0].State'
```

---

### 🧹 (Optional) Cleanup Old AMIs & Snapshots

#### List AMIs Created by You

```shell
aws ec2 describe-images --owners self \
  --filters "Name=name,Values=$AMI_NAME*" \
  --query 'Images[*].{ID:ImageId,Name:Name,CreationDate:CreationDate}' \
  --output table
```

#### Deregister Old AMI

```shell
aws ec2 deregister-image --image-id "$AMI_ID"
```

#### Delete Associated Snapshot

```shell
aws ec2 delete-snapshot --snapshot-id $SNAPSHOT_ID
```

---


## 🚀 GPU provisioning

### 1️⃣ Validate `gpu_remote_kernel_from_ami.yaml`

Install https://github.com/aws-cloudformation/cfn-lint for validation

```shell
cfn-lint gpu_remote_kernel_from_ami.yaml
```

### 2️⃣ Get your public IP

```shell
curl https://checkip.amazonaws.com
```

### 3️⃣ Deploy the CloudFormation stack

```shell
aws cloudformation deploy \
  --stack-name gpu-remote-kernel-ami \
  --template-file gpu_remote_kernel_from_ami.yaml \
  --parameter-overrides \
    KeyPairName=somesshkey \
    AllowedSSHLocation=<your-public-ip>/32 \
    PreBakedAmiId=$AMI_ID \
    InstanceType=g4dn.2xlarge \
  --region ap-south-1 \
  --capabilities CAPABILITY_NAMED_IAM
```

> Can use AllowedSSHLocation=0.0.0.0/0 if open SSH is needed, else restrict to your IP.

---

## 🧹 Full Cleanup Guide: Returning to a Clean State

### Delete the GPU instance stack (`gpu-remote-kernel-ami`)

```shell
aws cloudformation delete-stack --stack-name gpu-remote-kernel-ami
```

### 🔎 Helpful sanity checks

> Use these checks to verify and clean up resources that incur ongoing AWS costs if left behind after stack deletion.

#### Check all running EC2 instances:

```shell
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[*].{ID:InstanceId, State:State.Name}' \
  --output table
```

#### Check Elastic IPs:

```shell
aws ec2 describe-addresses \
  --query "Addresses[*].{PublicIp:PublicIp, AllocationId:AllocationId, AssociatedInstanceId:InstanceId}" \
  --output table
```

---
