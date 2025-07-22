# Resources and Pricing Impact

This document provides a breakdown of resources and associated pricing for the two-stack architecture:

- **Stack 1: GPU AMI Builder (`gpu_ami_builder.yaml`)** — defines AWS Image Builder infrastructure to create a reusable
  GPU-prepared AMI.
- **Stack 2: GPU Remote Kernel (`gpu_remote_kernel.yaml`)** — deploys a GPU-enabled EC2 instance from the baked AMI.

> 💡 **Note:** AWS Image Builder (`GPUInfraConfig`) incurs charges only during the short-lived AMI baking process (
> per-hour EC2 pricing). The baked AMI itself does not incur storage costs beyond standard AMI storage fees (typically
> negligible).

---

## 🔨 Stack 1: GPU AMI Builder (`gpu_ami_builder.yaml`)

| Resource Logical ID | Type                                             | Purpose                                       | Price Charged                            |
|---------------------|--------------------------------------------------|-----------------------------------------------|------------------------------------------|
| `InstanceRole`      | `AWS::IAM::Role`                                 | IAM role for Image Builder temporary instance | 🆓 Free                                  |
| `InstanceProfile`   | `AWS::IAM::InstanceProfile`                      | Attaches role to Image Builder instance       | 🆓 Free                                  |
| `GPUPrepComponent`  | `AWS::ImageBuilder::Component`                   | Defines install steps for bake                | 🆓 Free                                  |
| `GPUImageRecipe`    | `AWS::ImageBuilder::ImageRecipe`                 | Defines baked AMI structure                   | 🆓 Free                                  |
| `GPUInfraConfig`    | `AWS::ImageBuilder::InfrastructureConfiguration` | EC2 launch infra for bake                     | 💸 EC2 usage billed per-hour during bake |
| `GPUImagePipeline`  | `AWS::ImageBuilder::ImagePipeline`               | Defines bake workflow                         | 🆓 Free                                  |

---

## 🚀 Stack 2: GPU Remote Kernel (`gpu_remote_kernel.yaml`)

| Resource Logical ID           | Type                                    | Purpose                         | Price Charged                                      |
|-------------------------------|-----------------------------------------|---------------------------------|----------------------------------------------------|
| `RemoteKernelVPC`             | `AWS::EC2::VPC`                         | Virtual network for isolation   | 🆓 Free                                            |
| `PublicSubnet`                | `AWS::EC2::Subnet`                      | Subnet for public IP assignment | 🆓 Free                                            |
| `InternetGateway`             | `AWS::EC2::InternetGateway`             | Internet access                 | 🆓 Free                                            |
| `AttachGateway`               | `AWS::EC2::VPCGatewayAttachment`        | IGW attachment                  | 🆓 Free                                            |
| `PublicRouteTable`            | `AWS::EC2::RouteTable`                  | Routing                         | 🆓 Free (first 200 per VPC)                        |
| `PublicRoute`                 | `AWS::EC2::Route`                       | Default route                   | 🆓 Free                                            |
| `SubnetRouteTableAssociation` | `AWS::EC2::SubnetRouteTableAssociation` | Route table association         | 🆓 Free                                            |
| `ElasticIP`                   | `AWS::EC2::EIP`                         | Static public IP                | 🆓 Free while attached; 💸 $0.005/hr if unattached |
| `InstanceRole`                | `AWS::IAM::Role`                        | Runtime instance permissions    | 🆓 Free                                            |
| `InstanceProfile`             | `AWS::IAM::InstanceProfile`             | Attach role to runtime instance | 🆓 Free                                            |
| `InstanceSecurityGroup`       | `AWS::EC2::SecurityGroup`               | SSH ingress control             | 🆓 Free                                            |
| `GPUInstance`                 | `AWS::EC2::Instance`                    | Actual GPU instance             | 💸 ~$0.60/hr for `g4dn.xlarge` (Mumbai)            |
| `EIPAssociation`              | `AWS::EC2::EIPAssociation`              | Associates Elastic IP           | 🆓 Free while associated                           |