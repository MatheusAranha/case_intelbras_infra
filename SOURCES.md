# Sources and methodology

How the numbers in [PROPOSAL.md](PROPOSAL.md) were produced: what was looked up, what
was reasoned from the backend's own documentation, and what is genuinely just an
estimate that still needs a real load test. Read this if you're deciding how much to
trust a specific number before using it in a real budget or capacity conversation.

## 1. Pricing sources

Gathered via web search in October 2026, **us-east-1, on-demand, no committed-use
discount**. Nothing here comes from the AWS Pricing API or a logged-in Pricing
Calculator session — every figure is from a public pricing page or a third-party price
tracker, cross-checked against each other where more than one source was available.
Pricing changes; re-verify anything load-bearing at
[calculator.aws](https://calculator.aws/) before committing to a number.

| Figure used in PROPOSAL.md | Value | Source(s) | Confidence |
|---|---|---|---|
| MSK `kafka.t3.small` broker | $0.0456/hr | [Airbyte — Apache Kafka Pricing guide](https://airbyte.com/data-engineering-resources/apache-kafka-pricing) | Medium — single third-party source |
| MSK `kafka.m5.large` broker | $0.21/hr | [AWS MSK pricing page](https://aws.amazon.com/msk/pricing/) (worked example), corroborated by [factualminds' MSK calculator](https://www.factualminds.com/tools/amazon-msk-pricing-calculator/) (cites "us-east-1 list rates, as of 2026-07-09") | High — matches AWS's own example |
| MSK storage | $0.10/GB-month | Same AWS pricing page example + factualminds calculator | High |
| Fargate (Linux/x86) | $0.04048/vCPU-hr, $0.004445/GB-hr | [Vantage — AWS Fargate Pricing Explained](https://www.vantage.sh/blog/fargate-pricing), [Cloudchipr — AWS Fargate Pricing Explained](https://cloudchipr.com/blog/aws-fargate-pricing) | Medium — two third-party sources agree, official AWS page wasn't returned directly |
| RDS PostgreSQL `db.t3.medium` | ~$0.072/hr | [Sparecores](https://sparecores.com/database/aws/db.t3.medium), [Bytebase dbcost](https://www.bytebase.com/dbcost/rds/instance/db.t3.medium/), [cloudprice.net](https://cloudprice.net/aws/rds/instances/db.t3.medium) | Medium-high — three sources agree; one outlier source ([Holori](https://calculator.holori.com/aws/rds/db.t3.medium), $0.082/hr, dated Feb 2026) was noted and not used |
| NAT Gateway | $0.045/hr + $0.045/GB processed | [Cloudchipr — AWS NAT Gateway Pricing](https://cloudchipr.com/blog/aws-nat-gateway-pricing), [Cloudburn.io](https://cloudburn.io/blog/aws-nat-gateway-pricing) | Medium |
| Application Load Balancer | ~$0.0252/hr + $0.008/LCU-hr | [Cloudchipr — AWS Load Balancer Pricing](https://cloudchipr.com/blog/aws-load-balancer-pricing) | Medium — single source, hourly rate given as "approximately" by that source itself |
| Amazon Managed Grafana | $9/user (Admin/Editor), $5/user (Viewer) | [AWS Grafana pricing page](https://aws.amazon.com/grafana/pricing) (official, returned directly) | High |
| Amazon Managed Prometheus (AMP) | $0.90/10M samples (first 2B), $0.03/GB-month storage | [Sysdig — Managed Service for Prometheus](https://www.sysdig.com/blog/managed-service-prometheus) | **Low** — this source is dated April 2023 by its own byline; the official AWS AMP pricing page was not returned by search. The AMP line in PROPOSAL.md's cost table (~$5/month) is low enough in absolute terms that even a large relative error here barely moves the baseline total — but don't reuse this specific per-sample rate elsewhere without re-checking it |
| CloudWatch Logs ingestion | $0.50/GB | **Not sourced via search this session** — recalled from general AWS knowledge, not independently re-verified here. This has been a stable, long-standing CloudWatch rate, but treat it as unconfirmed for this proposal specifically |
| ECR storage, Secrets Manager, SNS | Small flat/per-unit rates | Not individually searched — these are well-known, low, and a small fraction of the total ($1-2/month range each); bundled into the table's "~$5/month" catch-all row rather than cited precisely |

Two search queries that came back **without a usable number** are worth noting
explicitly, since their absence shaped how the proposal is worded:
- No official AWS RDS PostgreSQL pricing page was returned with an us-east-1 rate table
  — the $0.072/hr figure is a third-party consensus, not a page off aws.amazon.com.
- No official AWS MSK or AMP pricing page returned a full rate table either — only the
  AWS MSK page's single worked example (`kafka.m5.large` at $0.21/hr) was an actual AWS
  source among the MSK/AMP figures.

**What this means for PROPOSAL.md's ~$340/month baseline total**: it's a reasonable
planning number built from real (mostly third-party-corroborated) prices, not something
to quote as a committed budget. The individual line items most worth re-verifying
first, in order, are AMP (lowest confidence) and CloudWatch Logs (unsourced this
session) — though neither is large enough to meaningfully change the total even if
each were off by 2-3x.

## 2. Capacity estimation methodology

PROPOSAL.md's §4 claims ~150–400 events/sec sustained at the baseline tier
(~13M–35M events/day). Here's exactly how that range was built, and which parts of it
are reasoning versus which parts are an actual citation.

### Step 1 — identify the real bottleneck

The backend's own `ARCHITECTURE.md` (written and reviewed as part of this same case,
see `case_intelbras_kafka_java/ARCHITECTURE.md` → *Idempotency at scale*) already
established that this application's throughput ceiling is **not** Kafka's raw
byte/message throughput — Kafka moves far more than this workload produces — but the
**one-DB-round-trip-per-event** audit path: `existsByDedupKey` (a `SELECT`) followed by
an `INSERT`, once per processed event. That document estimated **~50–100 events/sec per
consumer thread** from that constraint.

**This 50–100 figure itself is a reasoned estimate from that document, not an
independent citation or a benchmark result.** It was derived there from general
knowledge of simple indexed-point-query + single-row-insert round-trip costs on modest
Postgres hardware, not from running a load test against this schema. This proposal
inherits that estimate rather than re-deriving it — if you want a sourced number here,
that's the first thing to actually benchmark.

### Step 2 — map it onto this proposal's instance sizing

The baseline MSK cluster keeps the existing 3 partitions/topic × 4 topics = **12
Kafka partitions total**, and the ECS task definition's app container would run with
the same `concurrency = "3"` per listener the local app already uses (see
`KafkaTopics.PARTITIONS` and the `@KafkaListener` annotations in
`case_intelbras_kafka_java`) — so **12 consumer threads** is the ceiling Kafka itself
imposes, same as locally.

12 threads × 50–100 events/sec/thread = **600–1,200 events/sec theoretical ceiling**,
*if* the database could keep up with all 12 threads hammering it simultaneously.

### Step 3 — apply the real constraint: a burstable RDS instance

`db.t3.medium` is a **burstable** instance class (T-family): it has a baseline vCPU
performance level and a CPU credit balance that lets it exceed that baseline in bursts,
but a *sustained* high-query-rate workload — exactly what 12 threads continuously
hitting it would be — will exhaust that credit balance and throttle back to baseline
performance.

**No specific benchmark or AWS documentation page was looked up for "db.t3.medium
sustained OLTP throughput" in this session.** The 150–400 events/sec range is this
proposal's own reasoned estimate: it takes the 600–1,200 theoretical ceiling from Step 2
and discounts it for the burstable-CPU effect described above, landing well below the
thread-level ceiling. That discount factor (roughly 25–65% of theoretical) is a
judgment call, not a sourced number.

### Step 4 — the honest conclusion

PROPOSAL.md says this explicitly, and it's worth repeating here: **this is a reasoned
estimate built by composing one document's own estimate (Step 1) with general knowledge
of burstable-instance behavior (Step 3) — it has not been validated against a real
deployment.** The scaling-tier numbers in PROPOSAL.md §5 (e.g. ~1,000–2,500 events/sec
on `db.m5.large` + `kafka.m5.large`) are built the same way — same Step 1 and Step 2
math, with Step 3's discount removed because `db.m5.large` isn't burstable — so they
carry the same caveat.

The one way to turn any of these ranges into a real number: deploy this infrastructure,
then point `case_intelbras_kafka_java`'s own `POST /events/random-stream/start` at it
and ramp `eventsPerMinute` while watching `AuditConsumerLagHigh` in Grafana. That
endpoint exists specifically to answer this question empirically — see that project's
`ARCHITECTURE.md` → *Load generation: random event stream*. Until that test runs, every
events/sec number in this repo is a starting hypothesis for that test, not a capacity
guarantee.
