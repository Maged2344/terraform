# Terraform AWS End-to-End Lab — WordPress on AWS

In this lab **you build everything yourself with Terraform**: the remote state
backend (S3 + DynamoDB), the network, a WordPress EC2 instance backed by RDS,
and S3 media storage. At the end you will have deployed a full WordPress
platform end-to-end — and destroyed it cleanly.

**What you will practice**

- Remote state: S3 backend + DynamoDB state locking
- The core Terraform workflow: `fmt` → `validate` → `plan` → `apply` → `output` → `destroy`
- Networking, security groups, EC2 with `user_data`, RDS, S3, IAM roles, outputs

**Lab time:** 2–3 hours (the apply alone takes ~10 minutes — RDS is slow)
**Estimated cost:** a few cents if you destroy everything when finished

---

## Architecture — what you will build

```
                        ┌───────────────────────────────────────────────────┐
  Your workstation      │                    VPC  10.0.0.0/16               │
  ┌───────────┐         │                                                   │
  │ Browser   │ HTTP 80 │  ┌────────────────┐        ┌─────────────────────┐ │
  │           ├─────────┼─►│ PUBLIC SUBNET  │  3306  │  PRIVATE SUBNETS    │ │
  │  SSH ├────┼─────────┼─►│  EC2 Ubuntu    │───────►│  ┌───────────────┐  │ │
  └───────────┘         │  │  + Apache      │  RDS   │  │ RDS MySQL 8.0 │  │ │
        │               │  │  + PHP         │  SG    │  │ (not public)  │  │ │
        │ upload photo  │  │  + WordPress   │        │  └───────────────┘  │ │
        ▼               │  └───────┬────────┘        └─────────────────────┘ │
  ┌───────────┐         │          │ media uploads                          │
  │ S3 media  │◄────────┼──────────┘ (via EC2 instance role)                │
  │ bucket    │         │                                                   │
  └───────────┘         │   Remote state: S3 bucket + DynamoDB lock table   │
                        └───────────────────────────────────────────────────┘
```

| Component | Details |
|---|---|
| VPC | `10.0.0.0/16`, 1 public + 2 private subnets in different AZs |
| EC2 | Ubuntu 22.04, public subnet, Apache + PHP + WordPress installed by `user_data` |
| RDS | MySQL 8.0, private subnets only, reachable only from the WordPress SG |
| S3 | Media (uploads) bucket, private + versioned, written via the EC2 instance role |
| State | S3 bucket (versioned, encrypted) + DynamoDB `terraform-locks` table |

> A working reference implementation is in the [`solution/`](solution/) folder.
> **Try to build it yourself first** — use the solution only to check your work.

---

## Prerequisites

- [ ] Terraform >= 1.5 — check with `terraform version`
- [ ] AWS CLI v2 configured — check with `aws sts get-caller-identity`
- [ ] An EC2 key pair in your target region (EC2 → **Key pairs** → Create key pair) — note the name
- [ ] Your public IP — run `curl -s ifconfig.me`

---

## PHASE 1 — BOOTSTRAP THE REMOTE STATE BACKEND

The S3 state bucket and DynamoDB lock table **must exist before** you run
`terraform init` in the main project.

### Step 1.1 — Create the S3 state bucket (Console)

1. S3 → **Create bucket**
2. Name: something globally unique, e.g. `YOURNAME-terraform-state-2026-xxxx`
3. Keep **Block Public Access** enabled
4. Enable **Bucket Versioning**
5. Enable **default encryption (SSE-S3)**
6. Create it — do **not** use it for application uploads

### Step 1.2 — Create the DynamoDB lock table (Console)

1. DynamoDB → **Create table**
2. Table name: `terraform-locks`
3. Partition key: `LockID`, type **String**
4. Capacity: **on-demand** → Create

> Short on time? Use the ready-made bootstrap instead:
> `cd bootstrap && terraform init && terraform apply && terraform output`
> (it creates both resources; copy the `state_bucket_name` output).

### Step 1.3 — Create the main project folder

```bash
mkdir wordpress-terraform && cd wordpress-terraform
```

Create a file named `backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "YOUR-STATE-BUCKET-NAME"   # <-- from Step 1.1
    key            = "wordpress-lab/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### Step 1.4 — Initialize and verify

```bash
terraform init
```

If Terraform asks to migrate existing local state, review and confirm.

**Verify:**

- [ ] S3 → your state bucket → `wordpress-lab/` exists
- [ ] S3 → bucket → Properties → Versioning shows **Enabled**

### Step 1.5 — State locking test

1. Terminal 1: run `terraform plan` and let it run
2. Terminal 2: immediately run `terraform plan` again

- [ ] The second run should **wait or fail** with *"Error acquiring the state lock"*

> **Note:** DynamoDB-based locking is deprecated in current Terraform. This lab
> uses it because it is the learning objective. For new projects prefer
> S3-native locking with `use_lockfile = true` (Terraform 1.10+).

---

## PHASE 2 — BUILD THE INFRASTRUCTURE

Create these files in your `wordpress-terraform/` folder. Write the code
yourself — the requirements tell you exactly what each file must contain.
Use the AWS provider `~> 5.0` and pin `required_version >= 1.5.0` in `provider.tf`.

> Recommended naming/tagging: name every resource `"wordpress-lab-<thing>"`.
> Create a variable `project_name` (default `wordpress-lab`) and use it everywhere.

### File 1 — `provider.tf`

- AWS provider, region from a variable `aws_region` (default `us-east-1`)
- Bonus: add `default_tags` with `Project` and `ManagedBy = "terraform"`

### File 2 — `variables.tf`

Create these input variables:

| Variable | Type / default | Notes |
|---|---|---|
| `project_name` | string, `wordpress-lab` | used in all resource names |
| `vpc_cidr` | string, `10.0.0.0/16` | |
| `public_subnet_cidr` | string, `10.0.1.0/24` | |
| `private_subnet_cidrs` | list, `["10.0.11.0/24", "10.0.12.0/24"]` | |
| `availability_zones` | list, `["us-east-1a", "us-east-1b"]` | |
| `allowed_workstation_cidr` | string, **no default** | your IP + `/32`. Add a validation that rejects `0.0.0.0/0` |
| `ec2_ami_id` | string, default `null` | when null, fall back to a data source (see File 5) |
| `ec2_instance_type` | string, `t3.micro` | |
| `ec2_key_pair_name` | string, **no default** | your existing key pair |
| `db_name` | string, `wordpress` | |
| `db_instance_class` | string, `db.t3.micro` | |
| `db_username` | string, **no default**, `sensitive = true` | 1–16 alphanumeric chars |
| `db_password` | string, **no default**, `sensitive = true` | 8+ chars |

Then create `terraform.tfvars` (git-ignored — never commit secrets):

```hcl
allowed_workstation_cidr = "203.0.113.10/32"  # your IP
ec2_key_pair_name        = "my-keypair"
db_username              = "wpadmin"
db_password              = "ChangeMe-Please123!"
```

### File 3 — `vpc.tf` (Networking)

Required resources:

- [ ] `aws_vpc` — CIDR `10.0.0.0/16`, enable DNS support + DNS hostnames
- [ ] `aws_subnet` public — `10.0.1.0/24`, first AZ, `map_public_ip_on_launch = true`
- [ ] `aws_subnet` private ×2 — `10.0.11.0/24` and `10.0.12.0/24`, one per AZ
      (use `for_each` over the CIDR list — good practice!)
- [ ] `aws_internet_gateway` attached to the VPC
- [ ] `aws_route_table` public with route `0.0.0.0/0` → IGW
- [ ] `aws_route_table_association` for the public subnet
- [ ] Private route tables (local traffic only) + associations for both private subnets

### File 4 — `security.tf` (Security)

- [ ] `aws_security_group` `wordpress`:
      ingress **HTTP 80** from `allowed_workstation_cidr` only
      ingress **SSH 22** from `allowed_workstation_cidr` only
      egress all
- [ ] `aws_security_group` `rds`:
      ingress **MySQL 3306** from the **WordPress SG** (`security_groups = [aws_security_group.wordpress.id]`) — not a CIDR!

### File 5 — `ec2.tf` (Compute)

- [ ] `data "aws_ami"` — latest Ubuntu 22.04 (`ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*`, owner `099720109477`). Use it when `ec2_ami_id` is null
- [ ] `aws_instance` — public subnet, `associate_public_ip_address = true`, WordPress SG, your key pair
- [ ] `user_data` script that installs and configures:
      - `apache2`, PHP + modules (`php-mysql php-gd ...`), `unzip`, `mysql-client`
      - Download WordPress into `/var/www/html`
      - A `wp-config.php` pointing at the **RDS endpoint** with the DB name/user/password
      - Tip: render it with `templatefile()` so Terraform injects the DB values
- [ ] An IAM role + instance profile for the instance with access **only** to the
      media bucket (see File 7), so WordPress can use S3 without access keys
- [ ] Gotcha: `user_data` runs only on first boot — add
      `user_data_replace_on_change = true`

### File 6 — `rds.tf` (Database)

- [ ] `aws_db_subnet_group` using **both private subnets**
- [ ] `aws_db_instance`:
      - engine `mysql`, version `8.0`, class from `db_instance_class`
      - `db_name`, `username`, `password` from your sensitive variables
      - `vpc_security_group_ids` = the **RDS SG**
      - `publicly_accessible = false`
      - `skip_final_snapshot = true` (lab only)

### File 7 — `s3.tf` (Storage)

- [ ] `aws_s3_bucket` for WordPress media — name it
      `"${var.project_name}-media-${data.aws_caller_identity.current.account_id}"`
      (account ID keeps it globally unique)
- [ ] `aws_s3_bucket_versioning` — **Enabled**
- [ ] `aws_s3_bucket_public_access_block` — block everything
- [ ] `aws_s3_bucket_server_side_encryption_configuration` — SSE-S3
- [ ] Add `force_destroy = true` on the bucket so `terraform destroy` works with objects inside
- [ ] Scope the EC2 instance role policy to **this bucket only**
      (`s3:ListBucket` on the bucket, `Get/Put/DeleteObject` on `bucket/*`)

### File 8 — `outputs.tf`

Output all of: `vpc_id`, `public_subnet_id`, `private_subnet_ids`,
`ec2_public_ip`, `wordpress_url` (`http://<public ip>`), `rds_endpoint`,
`media_bucket_name`.

### File 9 — S3 media integration

Install the **Offload Media** plugin (`amazon-s3-and-cloudfront`) in wp-admin
(Settings → Plugins), and in `wp-config.php` define:

```php
define( 'AWS_USE_ROLE', true );
```

The plugin then uploads media to your S3 bucket using the **EC2 instance
role** — no access keys anywhere.

### Sanity check before applying

```bash
terraform fmt -recursive
terraform validate
terraform plan    # expect ~25-30 resources to add, zero to destroy
```

---

## PHASE 3 — APPLY, TEST & SUBMIT

### Step 3.1 — Apply

```bash
terraform apply     # ~10 minutes, mostly RDS
terraform state list
terraform output
```

### Step 3.2 — Verify the application

- [ ] WordPress page opens via the EC2 public IP — complete the install wizard
      (it connects to RDS using your `wp-config.php`)
- [ ] RDS has **no public IP** and sits in the private subnets (check console)
- [ ] RDS SG allows 3306 **only** from the WordPress SG; WordPress SG allows
      80/22 **only** from your IP
- [ ] Upload a photo in WordPress (Media → Add New) → the original object
      appears in the **media** bucket
- [ ] Terraform state object exists in S3 and versioning is enabled
- [ ] State locking demo done (Phase 1, Step 1.5)

### Step 3.3 — Evidence to submit

1. Successful `terraform apply`
2. VPC / subnets / route tables
3. WordPress page
4. RDS private settings + security group
5. S3 media bucket showing the uploaded image
6. Remote state object in S3
7. The state-lock error from the second terminal

---

## BONUS CHALLENGES

1. Add a second public subnet in another AZ + an ALB and Target Group for WordPress
2. Replace the single EC2 with an Auto Scaling Group and Launch Template
3. Split the project into modules: network, compute, database, storage
4. Add a NAT gateway so the private subnets have outbound internet access
5. Add dev/prod environments with Terraform workspaces
6. Replace the wp-config `templatefile()` with a fully dynamic configuration

---

## Cleanup

```bash
terraform plan -destroy   # review what will be removed
terraform destroy
```

All application resources are removed. **Preserve the state bucket and lock
table** until you no longer need the state — delete them last (Console, or
`terraform destroy` in the `bootstrap/` folder).

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `Error acquiring the state lock` | Another Terraform run holds the lock — wait, or `terraform force-unlock <LOCK_ID>` only if you are sure nothing is running |
| WordPress page doesn't load | Check `allowed_workstation_cidr` (only your IP is allowed); check the instance is running with a public IP |
| WordPress DB connection error | RDS takes ~10 min to become available; verify `rds_endpoint` matches your `wp-config.php` DB_HOST; verify the RDS SG allows 3306 from the WordPress SG |
| Site half-installed / `user_data` issues | `user_data` runs only on first boot. SSH in and check `sudo tail -100 /var/log/cloud-init-output.log`, or rebuild: `terraform apply -replace=aws_instance.wordpress` |
| S3 upload fails from WordPress | Check the instance role policy is scoped to the media bucket and `AWS_USE_ROLE` is defined |

### Reference docs

- HashiCorp S3 backend: https://developer.hashicorp.com/terraform/language/backend/s3
- State locking: https://developer.hashicorp.com/terraform/language/state/locking
- AWS provider docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
