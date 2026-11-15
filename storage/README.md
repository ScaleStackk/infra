# QuestaCase storage stacks

Upload these files independently to AWS CloudFormation:

- `neo4j-storage-stack.yaml` creates the graph-storage EC2 instance, retained
  50 GiB EBS data volume, Neo4j Browser on port 7474 and Bolt on port 7687.
- `qdrant-storage-stack.yaml` creates the vector-storage EC2 instance, retained
  50 GiB EBS data volume, Qdrant dashboard/REST on port 6333 and gRPC on 6334.

Both templates clone their public application repositories during bootstrap,
build the corresponding Docker image and start it with Docker Compose. Their
default `PublicIngressCidr` is `0.0.0.0/0` for the short-lived POC. Restrict it
to trusted `/32` addresses whenever possible.

The Hyderabad defaults use `t3.medium` in `ap-south-2b`. If that zone reports
insufficient capacity, select `ap-south-2c` through the `AvailabilityZone`
parameter without changing the template.

The Neo4j template includes a visible demo-only default password so the stack
can be created without entering one. Override `Neo4jPassword` for every shared
or longer-lived deployment. Never combine the published default password with
unrestricted public ingress outside a supervised demonstration.

The data volumes use `DeletionPolicy: Retain`; deleting a stack does not delete
its data volume or stop its EBS storage charges.
