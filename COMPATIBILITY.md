# Web API and KG worker compatibility

This note records the graph contract used by the QuestaCase POC. The repositories
do not publish semantic-versioned releases, so use the merge commits below as
known compatible checkpoints and record the deployed commit IDs in each
environment's change log.

## Compatible graph release

| Component | Compatible checkpoint | Required behavior |
|---|---|---|
| `kg_worker` | `93b5bca` (2026-11-22) | Imports shared CASE/STATUTE/SECTION/JUDGE/COURT nodes; records `document_ids`, `judgment_document_id`, and case `match_keys`; stores citation treatment and source evidence on relationships. |
| `webapi` | `5772417` (2026-11-22) | Queries shared graph nodes, resolves later treatment, returns overruled warnings, and includes source evidence plus optional presigned PDF links. |

These checkpoints are the merge commits for [kg_worker PR #2](https://github.com/ScaleStackk/kg_worker/pull/2)
and [webapi PR #1](https://github.com/ScaleStackk/webapi/pull/1). The API's new
graph behavior depends on the worker's shared-node fields. Deploy the pair
together for cross-judgment citations and later-treatment warnings. The API can
still query older document-scoped nodes, but cross-judgment results will be
missing until the graph is migrated.

## Neo4j migration

The worker checkpoint changes graph identity from document-scoped copies to
shared legal entities plus document-scoped facts and relationships. Existing
Neo4j data is not migrated in place automatically. Back up Neo4j, deploy the
new worker, then re-import every judgment before relying on cross-judgment
results. Re-import is scoped by document ID: the importer replaces that
document's graph data and preserves other judgments. Validate representative
cases, citations, shared nodes, and treatment edges before switching the API to
the new version.

Do not run the KG integration test against a production database: the test
fixture clears the Neo4j database it connects to. Use a throwaway database as
described in `kg_worker/tests/test_neo4j_integration.py`.

## Upload identity and event contract

The Web API publishes a UUID `documentId` in the `judgment.uploaded` event. The
KG and embedding workers must preserve this ID when writing their stores so API
filters and source links refer to the same uploaded judgment. The KG worker
stores the original upload event's S3 bucket/key in the event flow; the PDF
itself is not sent through Kafka.

For a deployment, record at minimum:

```text
webapi commit: <full SHA>
kg_worker commit: <full SHA>
Neo4j migration: <backup reference and completion time>
```

After upgrading, exercise one upload and query end-to-end. Confirm that the
answer's source includes a page, evidence quote, and (when S3 is configured) a
working PDF link; confirm that later treatment is scoped to uploaded judgments
and that an overruled case produces a warning. Citation influence counts, when
shown, describe only the uploaded corpus and do not establish whether a case
remains good law.
