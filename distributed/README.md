# QuestaCase cross-account compute stacks

This directory preserves the earlier cross-account compute topology. Use
`../application/application-node-stack.yaml` for the current central
application deployment; the CPU and GPU inference-node templates remain useful
when AWS-hosted inference nodes are required.

CloudFormation cannot create EC2 instances directly inside unrelated AWS
accounts from an ordinary single-account stack. Deploy these two templates:

- `inference-node-stack.yaml` once in every participant's AWS account.
- `cpu-inference-node-stack.yaml` for a slower CPU-only Qwen3 4B test node on
  `m7i-flex.large`. This is a lower-cost alternative to GPU inference, but Free
  Tier eligibility is account-specific and is not assumed.
- `webapi-node-stack.yaml` once in the central Web API account.

The Web API template uses the latest regional Amazon Linux 2023 x86-64 AMI. The
inference template uses the latest ECS-optimized Amazon Linux 2023 GPU AMI,
which includes NVIDIA drivers and the Docker GPU runtime. Both AMIs are resolved
through AWS Systems Manager public parameters. The templates create a VPC,
public subnet, internet gateway, encrypted gp3 root disk, security group, SSM
instance role and EC2 instance. No SSH port is opened.

The bootstrap process installs Docker and Git plus a pinned Docker Compose
plugin on the new instance, clones the public source repositories, builds the
relevant images and starts the container.
Logs are available at:

```text
/var/log/questacase-inference-bootstrap.log
/var/log/questacase-webapi-bootstrap.log
```

## 1. Choose non-overlapping networks

Example allocation:

| Owner | VPC CIDR | Subnet CIDR |
|---|---|---|
| Web API | `10.10.0.0/16` | `10.10.1.0/24` |
| Inference participant A | `10.20.0.0/16` | `10.20.1.0/24` |
| Inference participant B | `10.30.0.0/16` | `10.30.1.0/24` |
| Inference participant C | `10.40.0.0/16` | `10.40.1.0/24` |

## 2. Deploy every inference node

The flattened `inference` repository must first be published publicly. In
each participant's account:

```bash
export AWS_REGION_NAME=ap-south-2
export INFERENCE_REPOSITORY_URL=https://github.com/ScaleStackk/inference.git
export VPC_CIDR=10.20.0.0/16
export PUBLIC_SUBNET_CIDR=10.20.1.0/24
export INFERENCE_INGRESS_CIDR=0.0.0.0/0
export STACK_NAME=questacase-inference-participant-a

./deploy-inference.sh
```

Each participant sends the Web API owner these stack outputs:

- AWS account ID and Region
- `VpcId` and `VpcCidr`
- `RouteTableId`
- `SecurityGroupId`
- `PrivateIp`

The default is `g4dn.xlarge`, which provides four vCPUs, 16 GiB RAM, and one
NVIDIA T4 GPU. The generated container configuration requests that GPU. Confirm
that the selected Region has G4dn capacity and that the AWS account's **Running
On-Demand G and VT instances** quota is at least four vCPUs.

The default ingress CIDR exposes the unauthenticated Ollama API to the internet
for the controlled POC. Prefer `<web-api-public-ip>/32` once that address is
known. The `PublicInferenceEndpoint` output supplies the address to add to the
HAProxy backend list. The automatically assigned public IP and DNS name can
change after stopping and starting the instance.

## 3. Deploy the Web API node

```bash
export AWS_REGION_NAME=ap-south-2
export INFERENCE_REPOSITORY_URL=https://github.com/ScaleStackk/inference.git
export JUDGMENT_BUCKET_NAME=your-private-judgment-bucket
export KAFKA_BROKERS=10.10.2.10:9092
export INFERENCE_NODES=10.20.1.10:11434,10.30.1.10:11434

./deploy-webapi.sh
```

HAProxy can start before peering is active. It initially marks the remote nodes
unhealthy and automatically adds them to rotation when networking becomes
reachable.

## 4. Establish peering

For each inference account:

1. The Web API owner creates a VPC peering request using the two stack outputs.
2. The inference participant accepts it.
3. Add a Web API route for the inference VPC CIDR through that peering connection.
4. Add the inverse route in the inference route table.
5. Confirm TCP `11434` is allowed from the Web API VPC CIDR or security group.

Set the optional embedding, Qdrant and Neo4j variables before deployment when
those services are available. Values named `*API_KEY` and `*PASSWORD` are marked
as CloudFormation `NoEcho` parameters and written to a mode-0600 `.env` file.
Because bootstrapping injects them through EC2 user data, privileged AWS or host
administrators can still retrieve them. Use AWS Secrets Manager for production.

## HTTPS limitation

Port `8080` is restricted to `API_INGRESS_CIDR`, which defaults to the Web API VPC.
The Firebase frontend must not call an HTTP EC2 endpoint directly. Put the API
behind the HTTPS endpoint from the existing phase-one stack, an Application Load
Balancer, API Gateway, or a domain-based reverse proxy before exposing it.

## Cost and deletion

These stacks create billable EC2, EBS and public IPv4 resources. Deleting a stack
removes its instance and root disk. VPC peering connections and routes created
manually must also be removed manually.
