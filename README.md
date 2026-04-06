# TechCorp AWS Infrastructure — Terraform Assessment

A complete Terraform configuration that provisions a production-style web application
infrastructure on AWS, including VPC networking, EC2 instances, an Application Load
Balancer, and a PostgreSQL database server.

---

## Architecture Overview

```
Internet
   │
   ▼
[Application Load Balancer]  (public subnets — us-east-1a & 1b)
   │
   ├──▶ [Web Server 1]  (private subnet — us-east-1a)
   └──▶ [Web Server 2]  (private subnet — us-east-1b)

[Bastion Host]  (public subnet — us-east-1a, Elastic IP)
   │
   ├──▶ SSH into Web Server 1 / Web Server 2
   └──▶ SSH into DB Server

[DB Server]  (private subnet — us-east-1a)
   └── PostgreSQL 14
```

---

## Prerequisites

| Tool        | Minimum Version | Install Guide |
|-------------|-----------------|---------------|
| Terraform   | 1.3+            | https://developer.hashicorp.com/terraform/install |
| AWS CLI     | 2.x             | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html |
| AWS Account | —               | IAM user/role with EC2, VPC, ELB permissions |

Ensure your AWS credentials are configured:

```bash
aws configure
# Enter: AWS Access Key ID, Secret Access Key, region (us-east-1), output format (json)
```

---

## Repository Structure

```
terraform-assessment/
├── main.tf                        # All resource definitions
├── variables.tf                   # Variable declarations
├── outputs.tf                     # Output values
├── terraform.tfvars.example       # Template — copy and fill in
├── user_data/
│   ├── web_server_setup.sh        # Apache install + HTML page
│   └── db_server_setup.sh         # PostgreSQL install + DB setup
├── evidence/                      # Screenshots (add after deployment)
└── README.md
```

---

## Deployment Steps

### Step 1 — Clone / set up the project

```bash
git clone https://github.com/<your-username>/month-one-assessment.git
cd month-one-assessment
```

### Step 2 — Create your variable file

```bash
cp terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars` in your editor and fill in:

```hcl
region             = "us-east-1"
availability_zones = ["us-east-1a", "us-east-1b"]
my_ip_address      = "YOUR_PUBLIC_IP/32"   # curl https://checkip.amazonaws.com
bastion_password   = "YourStr0ngPassw0rd!" # used for ec2-user on all servers
key_pair_name      = ""                    # optional — leave empty for password-only
```

> ⚠️ **Never commit `terraform.tfvars` to Git** — it contains sensitive data.
> Add it to `.gitignore`.

### Step 3 — Initialise Terraform

```bash
terraform init
```

This downloads the AWS provider plugin.

### Step 4 — Preview the plan

```bash
terraform plan
```

Review the output carefully. You should see **~35 resources to be created**.
Take a screenshot of the plan output for your evidence folder.

### Step 5 — Apply (deploy)

```bash
terraform apply
```

Type `yes` when prompted. Deployment takes approximately **3–5 minutes**.

Once complete you will see outputs like:

```
Outputs:

bastion_public_ip       = "54.x.x.x"
db_server_private_ip    = "10.0.3.x"
load_balancer_dns       = "techcorp-alb-xxxxxxxxx.us-east-1.elb.amazonaws.com"
vpc_id                  = "vpc-xxxxxxxxxxxxxxxxx"
web_server_private_ips  = ["10.0.3.x", "10.0.4.x"]
```

---

## Verifying the Deployment

### Check the web app via the Load Balancer

Open the `load_balancer_dns` URL in your browser:

```
http://techcorp-alb-xxxxxxxxx.us-east-1.elb.amazonaws.com
```

Refresh a few times — you should see responses from **both** web servers (different instance IDs).

### SSH into the Bastion Host

```bash
ssh -o PasswordAuthentication=yes ec2-user@<bastion_public_ip>
# password: the value you set in bastion_password
```

### SSH from Bastion to a Web Server

Once inside the bastion:

```bash
ssh ec2-user@<web_server_private_ip>
# e.g. ssh ec2-user@10.0.3.45
# password: same bastion_password
```

### SSH from Bastion to the DB Server

```bash
ssh ec2-user@<db_server_private_ip>
# e.g. ssh ec2-user@10.0.3.100
```

### Connect to PostgreSQL on the DB Server

Once inside the DB server:

```bash
psql -h localhost -U techcorp_user -d techcorp_db
# Password: same bastion_password
```

Run a quick check:

```sql
\conninfo
\dt
\q
```

---

## Evidence Checklist

Capture screenshots and save them under `evidence/`:

- [ ] `01-terraform-plan.png` — full `terraform plan` output
- [ ] `02-terraform-apply.png` — `terraform apply` completion with outputs
- [ ] `03-aws-console-vpc.png` — AWS Console → VPC dashboard
- [ ] `04-aws-console-ec2.png` — AWS Console → EC2 instances list
- [ ] `05-aws-console-alb.png` — AWS Console → Load Balancer
- [ ] `06-alb-web-server-1.png` — Browser showing ALB URL → web server 1
- [ ] `07-alb-web-server-2.png` — Browser showing ALB URL → web server 2 (different instance ID)
- [ ] `08-ssh-bastion.png` — Terminal: SSH into bastion
- [ ] `09-ssh-web-server.png` — Terminal: SSH from bastion → web server
- [ ] `10-ssh-db-server.png` — Terminal: SSH from bastion → DB server
- [ ] `11-postgres-connect.png` — Terminal: `psql` session on DB server

---

## Cleanup (Destroy Infrastructure)

> ⚠️ This will permanently delete all provisioned resources. Ensure you have your evidence screenshots first.

```bash
terraform destroy
```

Type `yes` to confirm. This takes approximately **3–5 minutes** and will also release the Elastic IPs and NAT Gateways (which incur hourly charges when running).

---

**Tip:** Run `terraform destroy` when you are done to avoid ongoing charges.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| SSH password rejected | Confirm `PasswordAuthentication yes` in `/etc/ssh/sshd_config` on the target instance; user data may still be running — wait 2 mins |
| ALB health checks failing | Wait 2–3 minutes after apply for Apache to start; check Security Group allows port 80 from ALB |
| `Error: InvalidKeyPair.NotFound` | Either create the key pair in AWS Console first, or set `key_pair_name = ""` |
| NAT Gateway timeout | Ensure private route tables point to NAT GW, not IGW |
