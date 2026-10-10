# 3-Tier Web App on AWS (Terraform)

A modular Terraform project that deploys a 3-tier web application across two Availability Zones.

```
Internet
   |
[Public ALB]  ............................ public subnets (2 AZs)
   |
[Web tier: EC2 Auto Scaling group, nginx]  public subnets
   |  /api/ proxied to
[Internal ALB]  .......................... private app subnets (2 AZs)
   |
[App tier: EC2 Auto Scaling group, Python API]  private app subnets, outbound via NAT
   |  MySQL 3306, credentials from Secrets Manager
[RDS MySQL 8.0]  ......................... private DB subnets (no internet route)
```

## Layout

| Path | What it creates |
|---|---|
| `modules/network` | VPC, 2 public + 2 app + 2 DB subnets, internet gateway, NAT gateway, route tables |
| `modules/security` | One security group per tier, each allowing traffic only from the tier in front of it |
| `modules/database` | DB subnet group, custom parameter group, encrypted RDS MySQL with backups and a Secrets Manager password |
| `modules/app` | Internal ALB, least-privilege IAM role, launch template, Auto Scaling group, CPU scaling policy |
| `modules/web` | Public ALB, IAM role (Session Manager only), launch template, Auto Scaling group, CPU scaling policy |
| `.github/workflows/terraform.yml` | Optional CI: `terraform fmt` and `terraform validate` on every push |

## Run it from AWS CloudShell

```bash
# Every new CloudShell session: keep the large provider download out of the 1 GB home folder
export TF_DATA_DIR=/tmp/tfdata

cd three-tier
terraform init
terraform validate
terraform plan
terraform apply        # type "yes"; takes about 15 minutes, mostly RDS
terraform output
```

Open the `web_url` output in a browser. Give the instances 3 to 5 minutes after apply finishes.

## Tear down

```bash
export TF_DATA_DIR=/tmp/tfdata
terraform init         # only needed if this is a new CloudShell session
terraform destroy      # type "yes"
```

## Settings worth knowing

- `db_multi_az = true` adds a standby database in the second AZ.
- `db_backup_retention_days` defaults to 7. Lower it to 1 if a free-tier account rejects it.
- The NAT gateway, both ALBs and RDS bill by the hour. Destroy the stack when you are done.
