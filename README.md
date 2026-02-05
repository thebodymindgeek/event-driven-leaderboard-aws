# Event-Driven Leaderboard on AWS 

This project demonstrates how to transform a simple monolithic-style workload into an event-driven, serverless architecture on AWS using Terraform.

It simulates activity ingestion, processes events asynchronously, and builds a real-time leaderboard using managed AWS services.

---

## Architecture Overview

### Components

- Amazon DynamoDB
- DynamoDB Streams
- EventBridge Pipes
- Amazon SQS
- AWS Lambda
- Amazon SNS
- Amazon S3
- Amazon CloudWatch
- Terraform

### Flow

1. Activities are written to DynamoDB  
2. DynamoDB Streams emits events  
3. EventBridge Pipes routes events to SQS  
4. Lambda processes activities  
5. Scheduled Lambda rebuilds leaderboard  
6. Public Lambda URL serves data  
7. Static dashboard displays results  

---

## Repository Structure

```
.
├── infra/
├── lambdas/
├── templates/
├── dist/    
├── Makefile
└── README.md
```

---

## Prerequisites

- AWS CLI v2
- Terraform >= 1.5
- Python >= 3.10
- Make

Configure credentials:

```bash
aws configure
```

---

## Deployment

### Clone

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO
```

### Build Lambdas

```bash
make build
```

### Configure Terraform

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
```

Edit variables as needed.

### Deploy

```bash
make init
make apply
```
## ⚠️ Important: Confirm SNS Email Subscription

If you enabled email notifications, AWS requires manual confirmation.

After deployment:

1. Check your email inbox
2. Look for a message from AWS Notifications
3. Click **Confirm subscription**

Until this is confirmed, notifications will NOT be delivered.

You can verify the subscription in: 

AWS Console → SNS → Topics → edl-dev-notif → Subscriptions

---

## Run Demo

### Generate Activity

```bash
make simulate
```

### Rebuild Leaderboard

```bash
make rebuild
```

### View Dashboard

Get URL:

```bash
terraform output dashboard_url
```

Open in browser.

---

## Monitoring

Includes:

- CloudWatch dashboards
- Lambda error alarms
- SQS backlog alerts

---

## Makefile Commands

| Command | Description |
|---------|-------------|
| make build | Build Lambda packages |
| make init | Terraform init |
| make apply | Deploy infra |
| make destroy | Remove infra |
| make simulate | Generate events |
| make rebuild | Rebuild leaderboard |
| make fmt | Format Terraform |

---

## Cleanup

```bash
make destroy
```

---

## License

MIT
