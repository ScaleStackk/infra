# Local processing with AWS storage

This Compose stack simulates the complete QuestaCase processing design on one
computer while retaining all durable project data in AWS:

- PDFs remain in the existing private S3 bucket.
- Knowledge-graph data is read from and written to the existing AWS Neo4j host.
- Embeddings are read from and written to the existing AWS Qdrant host.
- Kafka, the Web API, KG worker, embedding worker/API, Ollama/Qwen inference,
  HAProxy load balancer and Next.js web app run as separate local containers.

The Compose file builds the existing sibling repositories directly. It does not
copy application source or require changes in any service repository. The
worker entrypoints are overridden to run their existing Kafka consumers.

## Prerequisites

1. Docker Desktop with Docker Compose.
2. Enough local memory for Qwen 4B and the remaining containers. Allocate at
   least 12 GB to Docker Desktop when practical.
3. AWS credentials with the same scoped S3 object permissions used by the EC2
   workers and Web API.
4. The Neo4j security group must permit your current public IP on TCP 7474.
5. The Qdrant security group must permit your current public IP on TCP 6333.
6. The S3 bucket CORS policy must permit `http://localhost:3000`.

The storage endpoints in `.env.example` are the last supplied Hyderabad
endpoints. If either EC2 instance was stopped and restarted without an Elastic
IP, update its hostname before running the stack.

## Configure

```bash
cd /Users/abhmya01/local_llm/infra/local
cp .env.example .env
```

Edit `.env` and replace the AWS access key, AWS secret key, Neo4j password,
Qdrant write key, Qdrant read-only key and embedding API key. `.env` is ignored
by Git and must not be committed.

## Build and run

Building downloads base images, Node/Python dependencies, the embedding model
and the Qwen model. Nothing is downloaded merely by adding this configuration.

```bash
./build.sh
./run.sh
```

Open `http://localhost:3000`, upload a PDF, and submit a query. The browser
uploads directly to S3 through the presigned URL. The Web API publishes the
document event to local Kafka; both local workers consume it independently and
write their results to the AWS storage instances.

Follow the full pipeline with:

```bash
docker compose --env-file .env -f compose.local.yaml logs -f \
  webapi kg-worker embedding-worker inference
```

Scale compute without changing code:

```bash
docker compose --env-file .env -f compose.local.yaml up -d \
  --scale kg-worker=2 --scale embedding-worker=2
```

Kafka has eight upload-topic partitions, so up to eight containers in each
worker group can actively process documents. The two worker types use different
consumer groups, ensuring both receive every uploaded judgment.

Stop local processing with:

```bash
./stop.sh
```

Stopping or deleting the local containers does not delete or modify AWS storage.
