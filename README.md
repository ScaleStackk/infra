# QuestaCase AWS infrastructure

This repository contains all AWS provisioning for QuestaCase. The current POC
deployment path is `application/`, `messaging/`, `workers/`, and `storage/`.

- `phase1-upload-stack.yaml` is retained only as the legacy combined
  upload/API/Kafka demonstration stack.
- `application/application-node-stack.yaml` provisions the Web API and
  inference load-balancer node.
- `application/cloudfront-webapi-stack.yaml` is the legacy optional CloudFront
  edge; the demo account could not create CloudFront distributions.
- `application/direct-https-edge-stack.yaml` is the no-CloudFront fallback. It
  opens ports 80/443 and starts Caddy on the existing application instance.
- `messaging/kafka-node-stack.yaml` provisions the dedicated Kafka node.
- `workers/worker-nodes-stack.yaml` provisions the KG and embedding workers.
- `distributed/` contains the earlier cross-account Web API topology plus
  reusable CPU and GPU inference-node stacks. The current central application
  node is provisioned from `application/application-node-stack.yaml`.
- `storage/` contains the Neo4j and Qdrant storage stacks.
- `local/` runs all processing services as local containers while continuing to
  use the AWS S3, Neo4j and Qdrant deployments for durable storage.

Runtime Docker and Compose files remain in their respective application
repositories and are cloned by these templates during EC2 bootstrap.

## Phase 1 upload stack

This section documents the retained legacy topology. Do not combine this stack
with the current separated application and Kafka stacks because it creates
overlapping responsibilities.

This CloudFormation stack creates the upload path needed by the Firebase UI:

- A private, encrypted and versioned S3 judgment bucket.
- S3 CORS for the two QuestaCase Firebase origins and local development.
- A new VPC, public subnet, internet gateway and security group.
- One Amazon Linux 2023 EC2 instance with an encrypted 30 GB gp3 root disk.
- An EC2 IAM role scoped to `GetObject` and `PutObject` under `judgments/`.
- Systems Manager access, so SSH port 22 is not opened.
- IMDSv2 with hop limit 2 so Docker can receive temporary role credentials.
- An Elastic IP and optional Route 53 record/Caddy HTTPS endpoint.
- Optional automatic Docker builds of the Web API and Kafka from public GitHub
  repositories.

## Application node

`application/application-node-stack.yaml` creates one EC2 instance and starts
two containers on it:

- `questacase-webapi`, exposed on port 8080;
- `questacase-inference-lb`, available to the Web API as
  `http://inference:11434` on the shared Docker network and to remote workers
  through the HTTPS edge at `/ollama/*`.

The template accepts the comma-separated inference nodes and the Neo4j,
Qdrant, and embedding API endpoints as parameters. It creates the private S3
bucket named by `JudgmentBucketName`, configures Firebase upload CORS, and gives
the EC2 role object access only under `JudgmentPrefix`. Supply the `KafkaBroker`
output from the messaging stack as the application stack's `KafkaBrokers`
parameter.

The application template requires the current Kafka, embedding, Neo4j, Qdrant,
and inference endpoints as stack parameters. This prevents a newly created
stack from silently using an obsolete public address. Storage credentials are
also required and are never inferred from the public endpoints.

If `ApiDomainName` and `Route53HostedZoneId` are supplied, Caddy is started as
an additional TLS edge container. Without a domain, the output is an HTTP URL,
which is useful for direct testing but cannot be called from an HTTPS Firebase
page because browsers block mixed content.

Caddy reserves `/ollama/*` for the inference gateway and strips that prefix
before forwarding to HAProxy on `127.0.0.1:11435`. Supply the resulting
`InferenceGatewayGenerateUrl` output to the worker stack. Workers must not point
directly at an Ollama node.

Neo4j, Qdrant, Kafka, extraction workers and inference nodes are not created by
the application stack.

The default `t3.small` is intended for a low-traffic demonstration. Increase
the instance type if multiple queries will run concurrently. Free Tier
eligibility varies by account and must be confirmed in the EC2 launch console;
the templates do not claim that larger compute-optimized defaults are free.

## CloudFront HTTPS edge

This is a retained optional/legacy path. The current POC uses
`application/direct-https-edge-stack.yaml` and Caddy, which also exposes the
HAProxy inference gateway at `/ollama/*`.

`application/cloudfront-webapi-stack.yaml` is a small, separate stack for the
already-running application node. It does not replace, restart, or modify the
EC2 instance. It creates a CloudFront distribution using the EC2 public DNS
hostname as a custom HTTP origin on port 8080. API caching is disabled, all API
methods are accepted, and viewer headers, cookies, and query strings are
forwarded to the origin.

Upload the template in the CloudFormation console. `OriginDomainName` must be
the EC2 public DNS hostname without a scheme, port, or path. After the stack and
CloudFront distribution finish deploying, copy the `HttpsApiBaseUrl` output and
use it as `NEXT_PUBLIC_BACKEND_URL` when building the Firebase frontend.

The default value currently targets the deployed application Elastic IP's EC2
DNS hostname:

```text
ec2-16-112-144-126.ap-south-2.compute.amazonaws.com
```

Test the `HealthCheckUrl` output before rebuilding the frontend. The existing
application security group must continue to allow CloudFront to reach TCP 8080.
For this POC it currently allows public access; a production deployment should
restrict origin access and add authentication and rate limiting.

If AWS has not yet verified the account for CloudFront, use
`application/direct-https-edge-stack.yaml`. Supply the application instance ID
and its security-group ID. The template defaults to the free testing hostname
`16-112-144-126.sslip.io`, opens ports 80 and 443, and runs Caddy through an SSM
State Manager association. Caddy obtains and renews the public certificate and
proxies API requests to the Web API on `127.0.0.1:8080` and `/ollama/*`
requests to HAProxy on `127.0.0.1:11435`.

The `sslip.io` hostname is appropriate for this short-lived POC but is a shared
public DNS service. Certificate issuance can occasionally be delayed by shared
certificate-authority rate limits. Use a domain you control for a durable or
production deployment. Deleting this auxiliary stack removes its ingress rules
and association, but it does not stop the already-created Caddy container; stop
that container separately before deleting the stack if it is no longer needed.

## Dedicated Kafka node

`messaging/kafka-node-stack.yaml` creates a minimal `t3.small` Amazon Linux
instance with a 20 GiB encrypted gp3 root disk and runs the `legal-kafka`
container. It has no Elastic IP. Kafka discovers and advertises the current EC2
public DNS name on every boot, and the stack outputs that address as
`KafkaBroker`.

Supply the Web API, KG-worker and embedding-worker public IPs as `/32` client
CIDRs. Kafka uses plaintext transport for this POC, so do not open port 9092 to
`0.0.0.0/0`. After a stop/start, update clients with the new Kafka public DNS
and update the stack's client CIDRs if any client public IPs also changed.

## Worker nodes

`workers/worker-nodes-stack.yaml` starts one KG worker and one embedding worker
host. Both default to `t3.small` for a low-cost POC. The embedding host also
runs the query-embedding API; choose a larger allowed instance type for sustained
ingestion or concurrent requests.

KG extraction defaults to `KgNumPredict=3000` and
`KgMaxBatchChars=12000`. The smaller semantic batches reduce truncated JSON
responses while preserving the existing retry behavior. The worker calls the
`InferenceGatewayGenerateUrl` output from the application or direct HTTPS edge
stack, not an Ollama node directly.

## Endpoint lifecycle

The Kafka, Neo4j, Qdrant, and embedding-worker stacks intentionally do not
allocate Elastic IPs. Their public IP addresses and public DNS names can change
after an EC2 stop/start. Before creating or updating the application and worker
stacks, copy the latest stack outputs into the endpoint parameters. Changing a
template in Git does not reconfigure already-running containers; update the
CloudFormation stack or rebuild/recreate the affected container explicitly.

## Before deployment

The template can create the infrastructure without source repositories. To also
start the application automatically, first push these directories to separate
public GitHub repositories:

- `local_llm/webapi` as the root of the Web API repository.
- `local_llm/msg_queue` as the root of the Kafka repository.

Supply both repository HTTPS URLs. Do not put a GitHub access token in a
CloudFormation parameter. A private source repository should instead use a
proper artifact deployment mechanism such as CodeDeploy or a private ECR image.

Firebase is served over HTTPS. For browser access to the API, supply a DNS name
from a Route 53 public hosted zone, such as `api.your-domain.example`. The stack
creates its A record and Caddy obtains and renews the TLS certificate. The
Firebase `web.app` domain cannot be reused as the EC2 API domain.

## Upload through the AWS console

1. Open **CloudFormation** in the region where the demo will run.
2. Choose **Create stack** and **With new resources**.
3. Select **Upload a template file** and upload `phase1-upload-stack.yaml`.
4. Enter the optional domain/hosted-zone pair and the two public repository URLs.
5. Acknowledge that the stack creates IAM resources, then create the stack.
6. Read `ApiBaseUrl` and `JudgmentBucketName` from the stack outputs.
7. Build the Firebase UI with `NEXT_PUBLIC_BACKEND_URL` set to `ApiBaseUrl`.

Leaving both repository URLs empty creates infrastructure only. Leaving both DNS
parameters empty skips the public HTTPS endpoint; the Firebase frontend cannot
call the API until HTTPS is configured.

## Deploy with the AWS CLI

The helper never installs software. It exits if the AWS CLI is unavailable.

```bash
cd /Users/abhmya01/local_llm/infra
chmod +x deploy.sh

export AWS_REGION_NAME=ap-south-1
export WEBAPI_REPOSITORY_URL=https://github.com/your-account/webapi.git
export KAFKA_REPOSITORY_URL=https://github.com/your-account/msg_queue.git
export API_DOMAIN_NAME=api.example.com
export ROUTE53_HOSTED_ZONE_ID=Z0123456789EXAMPLE

./deploy.sh
```

`parameters.example.json` is also provided for `create-stack` workflows. Replace
blank values before using it.

## Verification

After the stack reports `CREATE_COMPLETE`, bootstrap may still be building the
Docker images. Connect through Systems Manager using the output command and run:

```bash
sudo tail -f /var/log/questacase-bootstrap.log
sudo docker ps
curl -fsS http://127.0.0.1:8080/api/v1/health
```

Then test `https://your-api-domain/api/v1/health` externally. The health response
should report the upload pipeline as `configured`.

## Security and cost notes

- S3 Block Public Access stays fully enabled. Uploads use presigned URLs.
- Port 8080, Kafka and Docker are not exposed publicly; only ports 80 and 443 are
  open. Port 80 is used for certificate issuance and redirects.
- The API currently has no user authentication or rate limiting. Keep this as a
  controlled demo until authentication is added.
- The bucket is retained if the stack is deleted, protecting uploaded judgments.
- EC2, EBS, S3, data transfer, Route 53 and public IPv4 can incur charges.
- A single EC2 host and single Kafka broker are demonstration single points of
  failure, not a production high-availability design.
