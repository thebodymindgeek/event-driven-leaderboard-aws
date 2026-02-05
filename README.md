
# From Monolith to Event-Driven: AWS Leaderboard Demo

This repo is a portfolio demo that shows how a typical “early-stage” workflow (tight coupling, synchronous updates, limited failure isolation) can be evolved into an **event-driven** architecture on AWS using managed services.

The business scenario: employees complete activities in a wellness program; the system updates progress totals and a global leaderboard that can be viewed in a simple dashboard.

---

## What this builds (high level)

- **DynamoDB** tables for events + derived state
- **DynamoDB Streams** to capture activity inserts
- **EventBridge Pipes** to filter/route stream records
- **SQS (+ DLQ)** to buffer and isolate failures
- **Lambda** for asynchronous processing + leaderboard rebuild + API read
- **CloudWatch** logs/alarms/dashboard (if enabled in Terraform)
- **S3** static dashboard that reads from the API

> Optional: add `architecture.png` in the repo root if you want a visual. The demo works without it.

---

## Architecture (step-by-step flow)

1. **Activity ingestion**  
   A client (simulated by `activity-simulator` Lambda) writes activity events into the `Activities` DynamoDB table.

2. **Event capture**  
   DynamoDB Streams emits change records for new activity inserts.

3. **Routing + buffering**  
   EventBridge Pipes filters for `INSERT` events and pushes them to an SQS queue.

4. **Asynchronous processing**  
   `activity-processor` Lambda consumes from SQS and updates derived state:
   - `ProgramProgress` (per employee per program)
   - `EmployeeTotals` (global totals per employee)
   - `ProcessedEvents` (idempotency / dedup)

5. **Scheduled leaderboard refresh**  
   `leaderboard-rebuilder` Lambda runs on a schedule (EventBridge rule) and writes a top-N snapshot to `GlobalLeaderboard` (e.g., `LEADERBOARD_ID=GLOBAL`, `AS_OF=LATEST`).

6. **Serving**  
   `getleaderboard` Lambda is exposed via a **Function URL** and returns the latest leaderboard snapshot as JSON.

7. **Dashboard**  
   A static HTML dashboard hosted in S3 calls the Function URL and renders the leaderboard.

---

## Repo layout

```txt
.
├─ infra/          Terraform
├─ lambdas/        Lambda source code
├─ templates/      Dashboard template (Function URL injected by Terraform)
├─ dist/           Local build artifacts (zip files) - NOT committed
├─ Makefile
└─ README.md

Prerequisites

AWS account with permissions to create: DynamoDB, Lambda, SQS, EventBridge, IAM, CloudWatch, S3

AWS CLI configured locally (aws configure or SSO)

Terraform installed

zip installed (only needed if you use make build)

Deploy

From repo root:

make demo


This runs:

terraform fmt

terraform init

(optional) builds zip artifacts into dist/

terraform apply

prints outputs

If you want to run steps manually:

make init
make build     # optional depending on packaging approach
make deploy
make outputs

Run the demo
1) Generate activities

Invoke the activity-simulator Lambda a few times (AWS Console → Lambda → Test/Invoke).

This writes rows into the Activities table.

2) Confirm processing worked

Check DynamoDB tables:

ProgramProgress should increment counts/points

EmployeeTotals should increment totals

ProcessedEvents should contain processed event IDs

3) Confirm leaderboard updates

Because the rebuilder runs on a schedule, within the schedule interval you should see a refreshed snapshot item in GlobalLeaderboard (e.g., GLOBAL + LATEST).

4) View the dashboard

Open the S3 dashboard URL from Terraform outputs.
The page fetches the Function URL and displays the top leaderboard rows.

Teardown
make destroy

Notes

SQS provides buffering, failure isolation, and explicit retry semantics instead of coupling stream → lambda directly.

ProcessedEvents makes the processor idempotent to handle retries and duplicate deliveries safely.

Scheduled snapshot avoids doing expensive “rank top N” logic on every write and keeps reads cheap and fast.
