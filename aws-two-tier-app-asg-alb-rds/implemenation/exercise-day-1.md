# Week 3 Day 1 — Two-Tier App on EC2 (App + Local Postgres)

**Bootcamp:** July DevOps  
**Topic:** Dynamic 2-tier app · Postgres on EC2 · `DB_LINK` · backup with `pg_dump` · S3 + IAM role  
**Repo path:** `week3/src/`  
**Class:** Aug 8, 2026

---

## Overview

Last week you hosted a **static** site (nginx + HTML). Static apps do not store user data — for that you can also put files on S3.

Today you build a **dynamic (two-tier) app**:

| Tier | What | Where (today) |
|------|------|----------------|
| Application | Flask app (gunicorn) | Same EC2 |
| Data | PostgreSQL | Same EC2 (`localhost`) |

You will:

1. Launch one EC2 in a **public subnet**
2. Install and configure **Postgres**
3. Clone and run the Flask app with `DB_LINK`
4. Create some data (register, attendance, games, boards)
5. Take a **DB backup** with `pg_dump` and upload it to **S3** using an **IAM role** (no hardcoded AWS keys on the VM)

Tomorrow: move DB to RDS, restore this backup, then Auto Scaling Group + Load Balancer.

---

## What You Will Build

```
Internet → EC2 public IP:8000 → Flask (gunicorn)
                                    ↓
                              Postgres (localhost:5432)
                                    ↓
                         pg_dump → flaskapp.dump → S3
```

No nginx / load balancer for this lab — traffic hits the app port directly. Routing and reverse-proxy roles move to the load balancer in the next class.

---

## Concepts (read before the lab)

### Two-tier vs static

- **Static:** HTML/CSS/JS only. No user writes. Host on S3 or a simple nginx EC2.
- **Two-tier:** **App tier** + **data tier**. Users can register, post, save attendance — data persists in a database.
- Nginx (or Caddy, HAProxy, Traefik) in front of an app is still often counted as **two-tier** (proxy is not a data tier). Some call nginx a third “presentation” layer; for this bootcamp, **two-tier = app + DB**.

### Why one VM + local DB does not scale

If you copy the same VM three times, each copy has **its own database**. User A writes on instance 1; later the load balancer sends them to instance 2 → **data looks missing**. Writes must go to **one** database. Reading from one shared DB from many app instances is fine; writing to multiple independent DBs is not.

So for scale later: **app instances are stateless** (many VMs); **database is external** (one RDS). Today we keep DB on the same VM only so you can practice install, connect, backup, and migrate.

### Forward proxy vs reverse proxy (short)

| Type | Who sits behind it | Example |
|------|--------------------|---------|
| **Forward proxy** | Client | VPN — ISP/server sees proxy IP, not your real client IP |
| **Reverse proxy** | Server / apps | nginx, ALB — clients hit the proxy; they do not need the app’s private IP |

Today the app listens on `:8000` with a public IP. Later the ALB is the reverse proxy; app VMs can stay private (no public IP).

### `DB_LINK` connection string

Apps should **not** hardcode DB credentials in source. Pass a URL via environment variable:

```text
DB_LINK="postgresql://<username>:<password>@<host>:<port>/<db_name>"
```

Lab values:

| Field | Value |
|-------|--------|
| host | `localhost` (or `127.0.0.1`) |
| port | `5432` |
| username | `postgres` |
| password | `Admin1234` |
| db_name | `flaskapp` |

```bash
export DB_LINK=postgresql://postgres:Admin1234@localhost:5432/flaskapp
```

The app reads this with something like `os.getenv("DB_LINK", ...)` and falls back to SQLite only if unset — **use Postgres for this exercise**.

---

## Prerequisites

- [ ] Custom VPC (July VPC) with a **public subnet** (route `0.0.0.0/0` → Internet Gateway)
- [ ] SSH key pair
- [ ] Security group allowing **SSH (22)** and later **TCP 8000**
- [ ] Repo access: `https://github.com/akhileshmishrabiz/july-devops`

---

## Part 1 — Launch the EC2

1. EC2 → **Launch instance**
2. AMI: **Amazon Linux 2023**
3. Instance type: `t3.medium` (or `t3.small` for lab)
4. Key pair: your `.pem`
5. Network:
   - VPC: your July VPC
   - Subnet: **public** subnet (not private — you need SSH + browser access)
   - Auto-assign public IP: **Enable**
6. Security group (start with SSH; add 8000 in Part 4):

| Type | Port | Source |
|------|------|--------|
| SSH | 22 | Your IP (or `0.0.0.0/0` for lab) |

7. Launch and note the **public IP**.

SSH in:

```bash
ssh -i ~/path/to/key.pem ec2-user@<PUBLIC_IP>
```

```bash
sudo su -
cd /home/ec2-user
```

**Deliverable:** SSH works on a public-subnet EC2.

---

## Part 2 — Install and configure Postgres

### Step 2.1: Install and start

```bash
sudo dnf update -y
sudo dnf install postgresql15-server postgresql15 -y
sudo postgresql-setup --initdb
sudo systemctl start postgresql
sudo systemctl enable postgresql
sudo systemctl status postgresql
```

Expect **active (running)** and enabled on boot.

### Step 2.2: Allow password auth (localhost)

Default `pg_hba.conf` often uses `ident` for local TCP, which breaks password login from the app. Switch host lines to `scram-sha-256`:

```bash
sudo sed -i '/^host/ s/ident$/scram-sha-256/' /var/lib/pgsql/data/pg_hba.conf
sudo systemctl reload postgresql
```

### Step 2.3: Set password and create database

```bash
sudo -u postgres psql
```

Inside `psql`:

```sql
ALTER USER postgres WITH PASSWORD 'Admin1234';
CREATE DATABASE flaskapp OWNER postgres;
\l
\q
```

### Step 2.4: Test connection

```bash
psql "postgresql://postgres:Admin1234@localhost:5432/flaskapp"
```

If you connect, `\dt` may show no tables yet — the **app creates tables** on first run. Exit with `\q`.

**Deliverable:** `psql` login with the connection string works.

---

## Part 3 — Run the Flask app

### Step 3.1: Clone the repo

```bash
sudo dnf install git -y
git clone https://github.com/akhileshmishrabiz/july-devops.git
cd july-devops/week3/src
```

### Step 3.2: Virtual environment + dependencies

Do **not** `pip install` into the system Python. Use a venv:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
chmod u+x run.sh
```

After `source`, your prompt should show `(.venv)`.

### Step 3.3: Export `DB_LINK` and start

```bash
export DB_LINK=postgresql://postgres:Admin1234@localhost:5432/flaskapp
echo "$DB_LINK"
./run.sh
```

`run.sh` starts **gunicorn**. Logs should show listening on `0.0.0.0:8000` (or similar).

If you see authentication failed:

1. Confirm password with `ALTER USER postgres WITH PASSWORD 'Admin1234';`
2. Confirm `pg_hba.conf` uses `scram-sha-256` and you reloaded Postgres
3. Re-export `DB_LINK` in the same shell where you run `./run.sh`

**Deliverable:** App process running; no DB auth errors in the log.

---

## Part 4 — Open port 8000 and use the app

### Step 4.1: Security group

Add inbound rule:

| Type | Port | Source |
|------|------|--------|
| Custom TCP | 8000 | `0.0.0.0/0` (lab) |

### Step 4.2: Browse and create data

Open:

```text
http://<PUBLIC_IP>:8000
```

Do enough to create real rows (needed for a useful backup):

- [ ] Register / login a user
- [ ] Add a student / mark attendance (if available)
- [ ] Use a board, tickets, or a game so tables are not empty

**Deliverable:** Screenshot of the app in the browser; some data in the DB.

Optional — check tables from the VM (stop the app or open a second SSH session):

```bash
psql "postgresql://postgres:Admin1234@localhost:5432/flaskapp" -c '\dt'
```

---

## Part 5 — Backup the database (`pg_dump`)

Stop or leave the app as you prefer; backup works while Postgres is up.

```bash
cd ~/july-devops/week3/src   # or wherever you work
pg_dump "postgresql://postgres:Admin1234@localhost:5432/flaskapp" -F c -f flaskapp.dump
ls -lh flaskapp.dump
```

| Flag | Meaning |
|------|---------|
| `-F c` | Custom format (good for `pg_restore`) |
| `-f` | Output file |

You will restore this dump into **RDS** in the next class.

**Deliverable:** `flaskapp.dump` file on the EC2 disk.

---

## Part 6 — Store the backup on S3 (IAM role, not access keys)

### Why S3?

DB dumps can grow large. In the cloud, long-lived files go to **object/blob storage** (S3) — like a durable “Google Drive” for objects. You do not keep important backups only on an EC2 disk that can be terminated.

### Step 6.1: Create a bucket

1. S3 → **Create bucket**
2. Name must be globally unique, e.g. `database-backup-<your-account-id>` (use hyphens, not underscores)
3. Keep defaults → Create

### Step 6.2: Access path vs auth (know this)

For EC2 → S3 you need:

1. **Network path** — public IP (or NAT for private subnet). Tomorrow: optional **VPC gateway endpoint** for S3 (private path, no data-transfer cost for gateway endpoints to S3).
2. **Auth** — prefer **IAM role on the instance**, not `aws configure` with long-lived access keys on the VM.

### Step 6.3: IAM policy + role for EC2

**Policy** (example name: `july-ec2-s3-db-backup`):

1. IAM → **Policies** → Create policy
2. Service: **S3** — allow List / Read / Write (lab: you may use AmazonS3FullAccess if a custom policy misbehaves; tighten later)
3. Resource: your backup bucket (preferred) or all buckets for lab
4. Create policy

**Role**:

1. IAM → **Roles** → Create role
2. Trusted entity: **AWS service** → **EC2**
3. Attach the policy above
4. Name e.g. `ec2-s3-upload` → Create

**Attach to instance:**

1. EC2 → select instance → **Actions** → **Security** → **Modify IAM role**
2. Choose `ec2-s3-upload` → Update
3. Wait ~10 seconds, then on the instance:

```bash
aws s3 ls
aws s3 ls s3://database-backup-<your-account-id>/
```

Amazon Linux AMIs usually include the AWS CLI. You should **not** need `aws configure` if the role is attached.

### Step 6.4: Upload the dump

```bash
aws s3 cp flaskapp.dump s3://database-backup-<your-account-id>/flaskapp.dump
aws s3 ls s3://database-backup-<your-account-id>/
```

Confirm the object in the S3 console.

**Deliverable:** `flaskapp.dump` visible in your S3 bucket.

---

## Part 7 — Short notes (from class)

Answer in your own words:

1. **Two-tier** — what are the two tiers? Why is nginx usually not counted as a third tier here?
2. Why is putting **Postgres on every Auto Scaling instance** a bad idea?
3. Write the `DB_LINK` pattern and fill it with today’s lab values.
4. Why use **env var** for `DB_LINK` instead of hardcoding in the app?
5. **Forward proxy** vs **reverse proxy** — one example each (VPN vs ALB/nginx).
6. **Vertical vs horizontal scaling** — one sentence each; which one do Auto Scaling Groups do?
7. Why prefer an **IAM role on EC2** over access keys for S3 upload?
8. What do `pg_dump` and (later) `pg_restore` do?

---

## Submission checklist

- [ ] EC2 in **public** subnet with public IP; SSH works
- [ ] Postgres 15 installed, enabled, running
- [ ] Database `flaskapp` created; password auth works via `psql "..."`  
- [ ] App cloned from `week3/src`, venv active, deps installed
- [ ] `export DB_LINK=...` then `./run.sh` — app on port **8000**
- [ ] SG allows **8000**; browser shows the app
- [ ] Sample data created (users / attendance / boards / games)
- [ ] `flaskapp.dump` created with `pg_dump -F c`
- [ ] S3 bucket created; IAM role attached; dump uploaded with `aws s3 cp`
- [ ] Part 7 questions answered

---

## Quick reference

| Task | Command |
|------|---------|
| Start Postgres | `sudo systemctl start postgresql` |
| Status | `sudo systemctl status postgresql` |
| Admin shell | `sudo -u postgres psql` |
| App connect test | `psql "postgresql://postgres:Admin1234@localhost:5432/flaskapp"` |
| Venv | `python3 -m venv .venv && source .venv/bin/activate` |
| Deps | `pip install -r requirements.txt` |
| Run app | `export DB_LINK=... && ./run.sh` |
| Backup | `pg_dump "$DB_LINK" -F c -f flaskapp.dump` |
| Upload | `aws s3 cp flaskapp.dump s3://<bucket>/flaskapp.dump` |
| List bucket | `aws s3 ls s3://<bucket>/` |

**App path in this repo:** `week3/src/`

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| No SSH / no public connectivity | Instance must be in a **public** subnet with public IP + IGW route |
| `postgresql-setup` / service missing | Install `postgresql15-server` and `postgresql15`; initdb before start |
| `psql` auth failed / app auth failed | Set postgres password; fix `pg_hba.conf` to `scram-sha-256`; `reload` Postgres; re-export `DB_LINK` |
| `pip: command not found` or wrong packages | Activate venv: `source .venv/bin/activate` |
| Browser cannot open `:8000` | Open TCP **8000** in security group; confirm gunicorn listening |
| App falls back to SQLite | `DB_LINK` not exported in that shell — export again before `./run.sh` |
| `aws s3 ls` AccessDenied / Unable to locate credentials | Attach IAM role to instance; wait and retry; fix policy bucket ARN / permissions |
| Underscore in bucket name rejected | Use hyphens only in bucket names |

---

## Next class preview

- Launch template + **Auto Scaling Group** (min / max / desired, CPU scale policies)
- **RDS** Postgres (managed DB outside the ASG)
- Restore today’s dump with `pg_restore`
- **Application Load Balancer** in front of app instances
- Optional: VPC endpoint for S3; RDS Multi-AZ / read replicas / connection pooling (concepts)

Keep the S3 dump and this EC2 until you finish the restore lab — or at least keep the object in S3.

Good luck — get the two-tier app running and the backup into S3.
