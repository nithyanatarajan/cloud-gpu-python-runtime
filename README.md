# Remote GPU Kernel Setup

This document provides a **step-by-step guide** for provisioning a pre-baked GPU-enabled EC2 instance on AWS using AWS
CloudFormation and Image Builder.

The setup enables you to quickly launch a GPU-accelerated EC2 instance, ready to run GPU-intensive workloads, by baking
all required drivers and software into a reusable AMI.

---

## 📦 Prerequisites

- AWS account with proper permissions (CloudFormation, EC2, Image Builder, IAM, SSM)
- AWS CLI installed and configured (`aws configure`)
- An existing SSH KeyPair in AWS (or create one beforehand)
- A public IP address to restrict SSH access (optional but recommended)

---

## 🔨 Step 1: Build the pre-baked AMI

### 1️⃣ Validate the Image Builder template

```shell
cfn-lint gpu_ami_builder.yaml
```

### 2️⃣ Deploy Image Builder infrastructure

```shell
aws cloudformation deploy \
  --stack-name gpu-ami-builder \
  --template-file gpu_ami_builder.yaml \
  --region ap-south-1 \
  --capabilities CAPABILITY_NAMED_IAM
```

### 3️⃣ Get the pipeline ARN

```shell
aws cloudformation describe-stacks \
  --stack-name gpu-ami-builder \
  --query "Stacks[0].Outputs[?OutputKey=='GPUImagePipelineArn'].OutputValue" \
  --output text

export PIPELINE_ARN=$(aws cloudformation describe-stacks \
  --stack-name gpu-ami-builder \
  --query "Stacks[0].Outputs[?OutputKey=='GPUImagePipelineArn'].OutputValue" \
  --output text)
echo $PIPELINE_ARN
```

### 4️⃣ Start the image build manually

```shell
aws imagebuilder start-image-pipeline-execution --image-pipeline-arn $PIPELINE_ARN

# check if the pipeline execution started successfully
aws imagebuilder get-image-pipeline --image-pipeline-arn $PIPELINE_ARN
```

### 5️⃣ List all images built by the pipelines

```shell
# List all images built by the pipelines
aws imagebuilder list-images --owner Self \
  --query "imageVersionList[*].[arn, name, version, status]" \
  --output table
```

### 6️⃣ Find the latest image build version

```shell
# Get the latest image version ARN
BUILD_VERSION_ARN=$(aws imagebuilder list-images --owner Self \
  --query "imageVersionList[?starts_with(name, 'gpu-prep-recipe')].arn | [0]" \
  --output text)

# Check the details of the latest image build
aws imagebuilder get-image --image-build-version-arn "$BUILD_VERSION_ARN"
```

### 7️⃣ Find the AMI ID once build completes

```shell
aws ec2 describe-images \
  --owners self \
  --filters Name=name,Values=gpu-prep-recipe* \
  --query 'Images[0].ImageId' \
  --output text

export GPU_AMI_ID=$(aws ec2 describe-images \
  --owners self \
  --filters Name=name,Values=gpu-prep-recipe* \
  --query 'Images[0].ImageId' \
  --output text)

echo $GPU_AMI_ID
```

---

## 🚀 Step 2: Deploy GPU instance from baked AMI

### 1️⃣ Validate `gpu_remote_kernel.yaml`

```shell
cfn-lint gpu_remote_kernel.yaml
```

### 2️⃣ Deploy the stack

```shell
aws cloudformation deploy \
  --stack-name gpu-remote-kernel \
  --template-file gpu_remote_kernel.yaml \
  --parameter-overrides \
    KeyPairName=somesshkey \
    AllowedSSHLocation=<your-public-ip>/32 \
    InstanceType=g4dn.xlarge \
    PreBakedAmiId=$GPU_AMI_ID \
  --region ap-south-1 \
  --capabilities CAPABILITY_NAMED_IAM
```

---

## 📝 SSH into your instance and test

```shell
export AWS_ELASTIC_IP=$(aws cloudformation describe-stacks \
  --stack-name gpu-remote-kernel \
  --query "Stacks[0].Outputs[?OutputKey=='PublicIP'].OutputValue" \
  --output text)

ssh -i <your-keypair.pem> ubuntu@$AWS_ELASTIC_IP

nvidia-smi
```

---

## 🧹 Full Cleanup Guide: Returning to a Clean State

### 1️⃣ Delete the GPU instance stack (`gpu-remote-kernel`)

```shell
aws cloudformation delete-stack --stack-name gpu-remote-kernel
```

### 2️⃣ Delete the AMI builder infrastructure stack (`gpu-ami-builder`)

```shell
aws cloudformation delete-stack --stack-name gpu-ami-builder
```

### 3️⃣ Deregister the baked AMI

> Replace `<ami-id>` with the actual AMI ID you built and used.

```shell
aws ec2 deregister-image --image-id $GPU_AMI_ID
```

### 4️⃣ Find associated EBS snapshots for the deregistered AMI

```shell
aws ec2 describe-snapshots --owner-ids self \
  --query "Snapshots[?Description!=null && contains(Description, '$GPU_AMI_ID')].[SnapshotId,Description]" \
  --output table
```

### 5️⃣ Delete associated EBS snapshots

> Replace `<snapshot-id>` with snapshot IDs identified in the previous step.

```shell
aws ec2 delete-snapshot --snapshot-id <snapshot-id>
```

✅ After completing all these steps, your AWS account will be back to a clean state with **no lingering resources,
stacks, AMIs, or snapshots from this workflow**.

---

## 🔎 Helpful sanity checks

> Use these checks to verify and clean up resources that incur ongoing AWS costs if left behind after stack deletion.

### Check all running EC2 instances:

```shell
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[*].{ID:InstanceId, State:State.Name}' \
  --output table
```

> Billable while running. Stopped instances still incur EBS volume cost for their attached volumes.

### Check Elastic IPs:

```shell
aws ec2 describe-addresses \
  --query "Addresses[*].{PublicIp:PublicIp, AllocationId:AllocationId, AssociatedInstanceId:InstanceId}" \
  --output table
```

> Look for entries with `AssociatedInstanceId` as `null` → billable unattached IPs.

### Check EBS volumes:

```shell
aws ec2 describe-volumes \
  --query "Volumes[*].{VolumeId:VolumeId, State:State, Size:Size, AttachedTo:Attachments[0].InstanceId}" \
  --output table
```

> Billable whether attached or unattached.

### Check custom AMIs:

```shell
aws ec2 describe-images \
  --owners self \
  --query "Images[*].{ImageId:ImageId, Name:Name, CreationDate:CreationDate}" \
  --output table
```

> Billable for snapshot storage.
> Old custom AMIs = 💸 snapshot storage costs.

### Check EBS snapshots:

```shell
aws ec2 describe-snapshots \
  --owner-ids self \
  --query "Snapshots[*].{SnapshotId:SnapshotId, VolumeSize:VolumeSize, StartTime:StartTime}" \
  --output table
```

> Billable per GB-month until deleted.

---

## 🛠️ Troubleshooting

### "InsufficientInstanceCapacity" or "LimitExceeded" when creating GPU instance

AWS accounts have default limits (quotas) for GPU instances that may be set to `0` initially.

To check your current limits and request an increase:

#### **Check current quota:**

```shell
aws service-quotas get-service-quota   --service-code ec2   --quota-code L-DB2E81BA   --region ap-south-1
```

#### **Request a limit increase using CLI:**

```shell
aws service-quotas request-service-quota-increase   --service-code ec2   --quota-code L-DB2E81BA   --desired-value 4   --region ap-south-1
```

Alternatively, submit a request manually:

- Go to the [AWS Service Quotas console](https://console.aws.amazon.com/servicequotas/home/services/ec2/quotas)
- Search for "Running On-Demand G and VT instances"
- Submit a **Request quota increase** for your desired instance type (`g4dn.xlarge`, `g5.xlarge`, etc.) in your target
  region (e.g., `ap-south-1`).

> ℹ️ Approval may take a few minutes to hours depending on your AWS account history.
