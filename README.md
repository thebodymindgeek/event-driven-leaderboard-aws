Event-Driven Leaderboard on AWS (Terraform Demo)

This project demonstrates how to transform a simple monolithic-style workload into an event-driven architecture using AWS serverless services and Terraform.

It implements an activity ingestion pipeline and a real-time leaderboard using DynamoDB, Lambda, SQS, EventBridge, and CloudWatch.

🏗 Architecture Overview
Data Flow

Activities are written to DynamoDB.

DynamoDB Streams emits change events.

EventBridge Pipes routes events to SQS.

Lambda processes activities and updates aggregates.

A scheduled Lambda rebuilds the leaderboard.

A public Lambda Function URL serves leaderboard data.

A static HTML dashboard fetches and displays results.

All infrastructure is provisioned using Terraform.

📁 Repository Structure
.
├── infra/          # Terraform infrastructure
├── lambdas/        # Lambda function source code
├── templates/      # HTML dashboard template
├── Makefile        # Automation commands
└── README.md

Generated (Not Committed)
dist/              # Lambda ZIP packages (generated locally)


The dist/ directory is created automatically during deployment and is ignored by Git.

⚙️ Prerequisites

You need:

AWS Account

AWS CLI v2

Terraform >= 1.5

Python 3.11+

Git

Configure AWS credentials:

aws configure


Or via environment variables.

🚀 Quick Start
1️⃣ Clone
git clone <your-repo-url>
cd <repo>

2️⃣ Configure Terraform
cp infra/terraform.tfvars.example infra/terraform.tfvars


Edit values as needed.

3️⃣ Deploy Infrastructure
make init
make plan
make apply


Terraform will:

Package Lambda functions

Create AWS resources

Upload dashboard

Configure scheduler and alarms

4️⃣ Get Dashboard URL

After deployment:

make outputs


Open the dashboard URL in your browser.

5️⃣ Run Demo (Generate Activity)

Invoke the activity simulator:

make simulate


Wait ~1 minute and refresh the dashboard.

🧩 Makefile Commands
Command	Description
make init	Initialize Terraform
make fmt	Format Terraform files
make plan	Preview infrastructure changes
make apply	Deploy infrastructure
make destroy	Destroy all resources
make outputs	Show Terraform outputs
make simulate	Run activity simulator
🔐 Security Notes

The leaderboard API uses a public Lambda Function URL (demo only).

No authentication is enabled.

Do not use this setup in production.

🧹 Cleanup

To remove all AWS resources:

make destroy

