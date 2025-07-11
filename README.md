# Remote GPU Kernel Setup

This document provides instructions for setting up a remote GPU kernel using AWS CloudFormation. The setup allows you to
run GPU-accelerated tasks on a remote instance.

## GPU provisioning

### Creating a Remote GPU Kernel on AWS

#### Validate CloudFormation template

Install https://github.com/aws-cloudformation/cfn-lint for validation

```shell
cfn-lint gpu_remote_kernel.yaml
```

#### Get your public IP

```shell
curl https://checkip.amazonaws.com
```

#### Deploy CloudFormation stack

Ensure you have a valid aws environment configured with the necessary permissions. Otherwise do `aws configiure` first

```shell
aws cloudformation create-stack \
  --stack-name gpu-remote-kernel \
  --template-body file://gpu_remote_kernel.yaml \
  --parameters \
    ParameterKey=KeyPairName,ParameterValue=somesshkey \
    ParameterKey=AllowedSSHLocation,ParameterValue=<your-public-ip>/32 \
    ParameterKey=InstanceType,ParameterValue=g4dn.xlarge \
  --region ap-south-1 \
  --capabilities CAPABILITY_NAMED_IAM
```

> Can use ParameterKey=AllowedSSHLocation,ParameterValue=0.0.0.0/0 if open SSH is needed, else restrict to your IP.

#### Check stack status

```shell
aws cloudformation describe-stacks --stack-name gpu-remote-kernel
```

```shell
aws cloudformation describe-stack-events --stack-name gpu-remote-kernel
```

#### Get connection details

```shell
export AWS_ELASTIC_IP=$(aws cloudformation describe-stacks \
  --stack-name gpu-remote-kernel \
  --query "Stacks[0].Outputs[?OutputKey=='PublicIP'].OutputValue" \
  --output text)

echo "Elastic IP: $AWS_ELASTIC_IP"
```

#### Test SSH connectivity

```shell 
ssh -i "$AWS_SSH_PEM_PATH" ubuntu@$AWS_ELASTIC_IP
nvidia-smi
```

#### Copy files to remote instance

```shell
scp -i $AWS_SSH_PEM_PATH ./medical_diagnosis_manual.pdf ubuntu@$AWS_ELASTIC_IP:/home/ubuntu/
scp -i $AWS_SSH_PEM_PATH ./watermarks.py ubuntu@$AWS_ELASTIC_IP:/home/ubuntu/
```

#### Add/Update an entry to `.ssh/config`

```shell
Host aws-gpu-mumbai
  HostName 113.123.58.0
  User ubuntu
  IdentityFile ~/.ssh/rsakey.pem
```

> Assuming AWS_ELASTIC_IP=113.123.58.0

#### Configure remote_ikernel on your Mac

```shell
pip install remote_ikernel

# Delete the kernel if it exists
remote_ikernel manage --delete rik_ssh_aws_gpu_mumbai_awsgpumumbai

# Add remote kernel configuration:
remote_ikernel manage --add \
  --interface ssh \
  --name "aws-gpu-mumbai" \
  --host aws-gpu-mumbai \
  --kernel_cmd="bash -c 'source /opt/miniconda/etc/profile.d/conda.sh && conda activate gpu-env && python -m ipykernel_launcher -f {connection_file}'"

```

#### Shutdown / clean up when done

```shell
aws cloudformation delete-stack --stack-name gpu-remote-kernel
```

### Sanity

#### EC2 Instances

```shell
#aws ec2 terminate-instances --instance-ids <InstanceId>

aws ec2 describe-instances \
  --query 'Reservations[*].Instances[*].{ID:InstanceId, State:State.Name}' \
  --output table
```

#### Elastic IPs

```shell
#aws ec2 release-address --allocation-id <AllocationId>

aws ec2 describe-addresses \
  --query "Addresses[*].PublicIp" \
  --output text
```

### Resources defined in the template

> Resources + Pricing impact

| **Resource Logical ID**       | **Type**                                | **Purpose**                       | **Price Charged**                                                    |
|-------------------------------|-----------------------------------------|-----------------------------------|----------------------------------------------------------------------|
| `RemoteKernelVPC`             | `AWS::EC2::VPC`                         | Virtual network for isolation     | 🆓 Free (no hourly charge for VPC itself)                            |
| `PublicSubnet`                | `AWS::EC2::Subnet`                      | Subnet for public IP assignment   | 🆓 Free                                                              |
| `InternetGateway`             | `AWS::EC2::InternetGateway`             | Enables Internet access           | 🆓 Free                                                              |
| `AttachGateway`               | `AWS::EC2::VPCGatewayAttachment`        | Attachment of IGW to VPC          | 🆓 Free                                                              |
| `PublicRouteTable`            | `AWS::EC2::RouteTable`                  | Route table for outbound traffic  | 🆓 Free (first 200 per VPC)                                          |
| `PublicRoute`                 | `AWS::EC2::Route`                       | Default route via IGW             | 🆓 Free                                                              |
| `SubnetRouteTableAssociation` | `AWS::EC2::SubnetRouteTableAssociation` | Associates subnet and route table | 🆓 Free                                                              |
| `ElasticIP`                   | `AWS::EC2::EIP`                         | Allocates static public IP        | 🆓 Free **while attached**; \~\$0.005/hr if allocated but unattached |
| `InstanceRole`                | `AWS::IAM::Role`                        | IAM permissions                   | 🆓 Free                                                              |
| `InstanceProfile`             | `AWS::IAM::InstanceProfile`             | Attach IAM role to EC2            | 🆓 Free                                                              |
| `InstanceSecurityGroup`       | `AWS::EC2::SecurityGroup`               | Controls network access           | 🆓 Free                                                              |
| `GPUInstance`                 | `AWS::EC2::Instance`                    | Actual compute instance           | 💸 \~\$0.60/hr for `g4dn.xlarge` (`ap-south-1` Mumbai)               |
| `EIPAssociation`              | `AWS::EC2::EIPAssociation`              | Associates Elastic IP with EC2    | 🆓 Free while associated                                             |

## Conda Setup

You 'll have to run the scripts of [conda_installation.sh](conda_installation.sh) within the EC2 instance to set up the
conda environment. It is not yet automated.

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
- Submit a **Request quota increase** for your desired instance type (`g4dn.xlarge`, `g5.xlarge`, etc.) in your target region (e.g., `ap-south-1`).

> ℹ️ Approval may take a few minutes to hours depending on your AWS account history.
