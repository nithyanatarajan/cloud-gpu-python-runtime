# Resources and Pricing Impact

This document provides a breakdown of resources and associated pricing for GPU Remote Kernel (`gpu_remote_kernel.yaml`)

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
