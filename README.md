# Remote GPU Kernel Setup

This document provides a **step-by-step guide** for setting up a remote kernel in GPU-enabled EC2 instance using AWS CloudFormation. The setup allows you to run GPU-accelerated tasks on a remote instance.


---

## 📦 Prerequisites

- AWS account with proper permissions (CloudFormation, EC2, Image Builder, IAM, SSM)
- AWS CLI installed and configured (`aws configure`)
- An existing SSH KeyPair in AWS (or create one beforehand)
- A public IP address to restrict SSH access (optional but recommended)

---

## 🚀 GPU provisioning

### 1️⃣ Validate `gpu_remote_kernel.yaml`

Install https://github.com/aws-cloudformation/cfn-lint for validation

```shell
cfn-lint gpu_remote_kernel.yaml
```

### 2️⃣ Get your public IP

```shell
curl https://checkip.amazonaws.com
```

### 3️⃣ Deploy the CloudFormation stack

```shell
aws cloudformation deploy \
  --stack-name gpu-remote-kernel \
  --template-file gpu_remote_kernel.yaml \
  --parameter-overrides \
    KeyPairName=somesshkey \
    AllowedSSHLocation=<your-public-ip>/32 \
    InstanceType=g4dn.2xlarge \
  --region ap-south-1 \
  --capabilities CAPABILITY_NAMED_IAM
```

> Can use AllowedSSHLocation=0.0.0.0/0 if open SSH is needed, else restrict to your IP.

### 4️⃣ Check stack status

```shell
aws cloudformation describe-stacks --stack-name gpu-remote-kernel
```

```shell
aws cloudformation describe-stack-events --stack-name gpu-remote-kernel
```

### 5️⃣ Get connection details

```shell
export AWS_ELASTIC_IP=$(aws cloudformation describe-stacks \
  --stack-name gpu-remote-kernel \
  --query "Stacks[0].Outputs[?OutputKey=='PublicIP'].OutputValue" \
  --output text)

echo "Elastic IP: $AWS_ELASTIC_IP"
```

### 6️⃣ Test SSH connectivity

```shell 
ssh -i "$AWS_SSH_PEM_PATH" ubuntu@$AWS_ELASTIC_IP
```

Alternately you can add entry to your `~/.ssh/config` file:

```plaintext
Host aws-gpu-mumbai
  HostName 113.123.58.0
  User ubuntu
  IdentityFile ~/.ssh/rsakey.pem
```

> Assuming AWS_ELASTIC_IP=113.123.58.0

Then use the alias to connect:

```shell
ssh aws-gpu-mumbai
```

### 7️⃣ Test Setup

#### Check if NVIDIA drivers are installed

```shell
# Within the EC2 instance, run:
nvidia-smi

## If not found, check if any dpkg locks are present:

# Identify the process holding the lock
sudo lsof /var/lib/dpkg/lock-frontend

# Verify what it’s doing
ps -fp <ProcessID>

# Monitor the process
tail -f /var/log/dpkg.log
```

#### Conda Setup

Check if conda is installed:

```shell
# Within the EC2 instance:
# check if conda is installed
source /opt/miniconda/etc/profile.d/conda.sh
conda --version
```

You 'll have to run the scripts of [conda_installation.sh](conda_installation.sh) within the EC2 instance to set up the
conda environment. It is not yet automated.

```shell
scp -i $AWS_SSH_PEM_PATH conda_installation.sh ubuntu@$AWS_ELASTIC_IP:/home/ubuntu/
```

> After copying the script, SSH into the instance and run it:
```shell
# Within the EC2 instance, run:
chmod +x conda_installation.sh
./conda_installation.sh
```

### 8️⃣ Configure remote_ikernel on your Mac

```shell
pip install remote_ikernel

# Delete the kernel if it exists
remote_ikernel manage --delete rik_ssh_aws_gpu_mumbai_awsgpumumbai

# Add remote kernel configuration:
remote_ikernel manage --add \
  --name "aws-gpu-mumbai" \
  --interface ssh \
  --host aws-gpu-mumbai \
  --kernel_cmd="bash -c 'source /opt/miniconda/etc/profile.d/conda.sh && conda activate gpu-env && python -m ipykernel_launcher -f {connection_file}'"

# Show configured remote kernels
remote_ikernel manage --show
```

---

## 🧹 Full Cleanup Guide: Returning to a Clean State

### Delete the GPU instance stack (`gpu-remote-kernel`)

```shell
aws cloudformation delete-stack --stack-name gpu-remote-kernel
```

### 🔎 Helpful sanity checks

> Use these checks to verify and clean up resources that incur ongoing AWS costs if left behind after stack deletion.

#### Check all running EC2 instances:

```shell
#aws ec2 terminate-instances --instance-ids <InstanceId>

aws ec2 describe-instances \
  --query 'Reservations[*].Instances[*].{ID:InstanceId, State:State.Name}' \
  --output table
```

> Billable while running. Stopped instances still incur EBS volume cost for their attached volumes.

#### Check Elastic IPs:

```shell
#aws ec2 release-address --allocation-id <AllocationId>

aws ec2 describe-addresses \
  --query "Addresses[*].{PublicIp:PublicIp, AllocationId:AllocationId, AssociatedInstanceId:InstanceId}" \
  --output table
```

> Look for entries with `AssociatedInstanceId` as `null` → billable unattached IPs.

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
