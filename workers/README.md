# QuestaCase worker nodes

`worker-nodes-stack.yaml` creates two public EC2 instances in Mumbai by default:

- a low-cost `t3.small` KG worker that calls the remote Qwen inference
  API and writes validated graphs to Neo4j;
- a low-cost `t3.small` embedding worker that writes document
  vectors to Qdrant and serves query embeddings on port 8081.

Free Tier eligibility depends on the AWS account. For sustained ingestion or
concurrent embedding requests, select one of the larger allowed instance types.

Both instances consume `judgment.uploaded` independently using different Kafka
consumer groups and download PDFs from the private `questacase` bucket through
their EC2 IAM role. `JudgmentBucketRegion` remains `ap-south-2`, so the Mumbai
workers address the Hyderabad S3 bucket correctly. They need no inbound SSH;
use Systems Manager Session Manager. Only the Web API Elastic IP can reach the
embedding API.

Before deploying, push the current `kg_worker` and `embed_worker` commits to
their public GitHub repositories because the EC2 bootstrap clones `main`.

KG requests use `KgNumPredict=3000` and `KgMaxBatchChars=12000` by default to
reduce incomplete JSON from long inference prompts. `InferenceGenerateUrl`
must be the application stack's HTTPS HAProxy gateway output.

After the stack completes:

1. Copy `KgWorkerKafkaClientCidr` and `EmbeddingWorkerKafkaClientCidr` from the
   outputs into the Kafka stack's allowed client CIDRs.
2. Copy `EmbeddingApiUrl` into the Web API stack and use the same
   `EmbeddingApiKey` supplied to this stack.
3. The worker containers automatically reconnect once Kafka permits their IPs.

The instances have ordinary public addresses, not Elastic IPs. After stop/start,
update the Kafka CIDRs and Web API embedding URL using the new outputs/addresses.
