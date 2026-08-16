# Week 3 Day 2 — Scale the Two-Tier App (RDS + ASG + ALB)

**Bootcamp:** July DevOps  
**Topic:** RDS Postgres · Launch template · Auto Scaling Group · Application Load Balancer · Route 53  
**Repo path:** `week3/src/` · helper files: `week3/implemenation/ec2-asg-alb/`  
**Class:** Aug 9, 2026  
**Builds on:** [exercise-day-1.md](./exercise-day-1.md) (local Postgres on one EC2)

---

## Overview

Day 1 ran a **monolith** Flask app with Postgres on the **same** EC2. That is fine for a small lab. To scale users you must:

1. Move the database **out** of the app VMs → **RDS**
2. Run app VMs in an **Auto Scaling Group** (private subnets, multi-AZ)
3. Send traffic through an **Application Load Balancer** (public subnets)
4. Optionally map a **domain** (Route 53) to the ALB DNS name

App instances stay **stateless**. All durable data lives in RDS.

---

## Architecture

```
Internet
   │
   ▼
Route 53 (optional) ──► ALB (public subnets, ≥2 AZs)
                           │
                           ▼
                    Target group (port 8000, health = /health)
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
         EC2 (ASG)    EC2 (ASG)    …  (private app subnets, ≥2 AZs)
              │            │
              └─────┬──────┘
                    ▼
         RDS Postgres (private DB subnets, Multi-AZ optional)
```

| Layer | Subnets | Why |
|-------|---------|-----|
| ALB | **Public** (≥2 AZs) | Internet-facing; needs IGW route |
| App ASG | **Private app** (≥2 AZs) | No public IP; outbound via **NAT** for `git`/`pip` |
| RDS | **Private DB** (≥2 AZs for subnet group) | No inbound/outbound internet; isolate from app routing |

**Minimum two AZs** for ALB and for ASG high availability. Two subnets in the **same** AZ do not give you AZ failure protection.

---

## Concepts (from class)

### Why separate public / private-app / private-DB subnets

- **ALB** must be public (clients hit it from the internet).
- **App** VMs should stay private (no direct public IP). They still need **outbound** internet for `git clone` / package install → **NAT Gateway** in a public subnet + private route `0.0.0.0/0` → NAT.
- **RDS** stays in isolated private subnets with **no** IGW/NAT routes. DB traffic only from app security groups on port **5432**.

### Launch template vs ASG networking

- Put **AMI, instance type, key (optional), IAM role, security group, user data** in the launch template.
- Prefer **subnet / AZ placement** in the **ASG**, not locked only in the template, so you control multi-AZ spread.

### User data vs golden AMI

| Approach | When |
|----------|------|
| **User data** | Few packages (`git`, venv, pip) — OK if boot stays short (seconds) |
| **Golden AMI + pipeline** | Many packages / long install — bake image, refresh every ~15 days for patches |

For this lab, user data is enough. Production often uses a golden-image pipeline and thin user data.

### ALB vs NLB (short)

| | ALB | NLB |
|--|-----|-----|
| OSI | Layer **7** (HTTP/HTTPS) | Layer **4** (TCP/UDP) |
| HTTPS / host/path rules | Yes | Not the usual choice for web apps |
| This lab | **Use ALB** | Assignment: compare both |

### How ALB sends traffic

```
Listener (e.g. :80) → rules → Target group → registered EC2s (ASG)
```

Target group runs **health checks**. Unhealthy targets get no traffic; ASG can replace them.

### RDS patterns (know the names)

| Pattern | Purpose | Trade-off |
|---------|---------|-----------|
| Single-AZ | Cheap lab / low criticality | Longer restore from snapshot if AZ fails |
| **Multi-AZ standby** (active-passive) | Fast failover (~minutes) | Pay for standby + cross-AZ replication lag (RPO) |
| Read replicas | Offload **reads** | Small lag; writes still one primary |
| Snapshot-only DR | Cheapest | Higher RTO/RPO (hours possible for large DBs) |

**RTO** = how fast you are back online. **RPO** = how much recent data you accept losing. Everything is a **trade-off** (cost vs downtime vs data loss).

### Lab SLA note (single-AZ RDS)

AWS single-AZ style SKUs advertise ~**99.5%** monthly uptime ≈ up to ~**3.6 hours** downtime/month. Multi-AZ raises the SLA. Pick for the business need, not habit.

---

## Corrections from class demo (do these — avoid the traps)

These are the fixes from the live troubleshooting. Follow them in order.

1. **NAT Gateway for private app subnets**  
   Without NAT, user data `git clone` / `pip install` **fails** on private instances (no path to the internet). Public test VMs worked; private ASG instances did not — that was NAT missing.

2. **Keep the app on port 8000**  
   Do **not** force gunicorn onto port 80 unless you run as root and accept the pain. Create the **target group for port 8000**.

3. **Health check path = `/health` (expect HTTP 200)**  
   `/` redirects to login (**301/302**). Default TG health wants **200**, so `/` looks unhealthy. Use `/health` (this app returns JSON `{"status":"healthy",...}`).

4. **Create security groups before the ASG**  
   Attach an **app SG** to the **launch template**. ASG create flow often will not let you pick SG later cleanly; default SG “all traffic from self” does **not** allow ALB → instance.

5. **Create Target Group + ALB yourself, then attach to ASG**  
   Letting ASG “create new load balancer” tends to default TG to port **80** and wrong health path. More control = fewer unhealthy loops.

6. **RDS security group: allow 5432 from the app SG**  
   Not `0.0.0.0/0` in real setups. Lab may open broadly once; tighten to app SG.

7. **Test user data on a public EC2 from the launch template first**  
   Confirm `http://<public-ip>:8000/health` before trusting ASG. Check `sudo cat /var/log/cloud-init-output.log` if clone/pip fails.

8. **Do not commit real DB passwords**  
   Lab may hardcode `DB_LINK` in user data. Production: Secrets Manager + IAM role on the instance.

---

## Prerequisites

- [ ] Day 1 done (optional but useful): S3 dump of local DB
- [ ] July VPC (or equivalent)
- [ ] Ability to create subnets, NAT, RDS, EC2, ALB
- [ ] Domain optional for Route 53 at the end

Suggested CIDR sketch (adjust to your VPC):

| Name | Example CIDR | AZ | Role |
|------|--------------|----|------|
| `public-1` | `10.0.5.0/24` | 1a | ALB + NAT |
| `public-2` | `10.0.6.0/24` | 1b | ALB |
| `private-app-1` | `10.0.1.0/24` | 1a | ASG |
| `private-app-2` | `10.0.2.0/24` | 1b | ASG |
| `private-rds-1` | `10.0.3.0/24` | 1a | RDS subnet group |
| `private-rds-2` | `10.0.4.0/24` | 1b | RDS subnet group |

---

## Part 1 — Networking prep

### Step 1.1: Subnets

Create the six subnets above (names can match class: `public-1/2`, `private-1/2`, `rds-1/2`).

### Step 1.2: Public route table

1. Route table `july-public` → associate `public-1`, `public-2`
2. Route: `0.0.0.0/0` → **Internet Gateway**

### Step 1.3: NAT + private app routes (required)

1. Create **NAT Gateway** in `public-1`, allocate Elastic IP
2. Route table `july-private` → associate `private-app-1`, `private-app-2`
3. Route: `0.0.0.0/0` → **NAT Gateway**

**Do not** attach NAT/IGW routes to RDS subnets.

### Step 1.4: Security groups (create now)

**`sg-alb`** (ALB)

| Inbound | Port | Source |
|---------|------|--------|
| HTTP | 80 | `0.0.0.0/0` |
| HTTPS | 443 | `0.0.0.0/0` (when you add certs) |

**`sg-app`** (ASG instances — attach in launch template)

| Inbound | Port | Source |
|---------|------|--------|
| Custom TCP | **8000** | `sg-alb` |
| SSH | 22 | Your IP (only if you test with a key; optional) |

**`sg-rds`**

| Inbound | Port | Source |
|---------|------|--------|
| PostgreSQL | **5432** | `sg-app` |

**Deliverable:** Diagram or notes of subnet + SG layout.

---

## Part 2 — Create RDS Postgres

1. RDS → **Create database** → Standard create
2. Engine: **PostgreSQL** (e.g. 16.x)
3. Templates: **Dev/Test** / Free tier–friendly for lab → **Single-AZ** (cheaper). Enable Multi-AZ later when you want the standby pattern.
4. Credentials (example — use your own):

| Field | Example |
|-------|---------|
| Master username | `admin_user` |
| Password | `Admin1234` |
| Initial DB name | `mydb` (Additional configuration — set explicitly) |

5. Instance: small (`db.t3.micro` / `db.t4g.micro` if available)
6. Storage: gp2/gp3 ~20–30 GB; optional storage autoscaling
7. Connectivity:
   - VPC: July VPC
   - **DB subnet group:** create with `private-rds-1` + `private-rds-2` only
   - Public access: **No**
   - Security group: `sg-rds`
8. Port: **5432**
9. Create and wait until **Available**
10. Copy **Endpoint** from Connectivity & security

Build `DB_LINK`:

```bash
export DB_LINK="postgresql://admin_user:Admin1234@<RDS_ENDPOINT>:5432/mydb"
```

Optional: restore Day 1 dump with `pg_restore` from a jump host/public tester that can reach RDS (SG + network path). If you skip restore, the app creates empty tables on first boot.

**Deliverable:** RDS endpoint + working `DB_LINK` string (keep password private).

---

## Part 3 — Launch template + user data

### Step 3.1: Edit user data file

File: [`ec2-asg-alb/user-data.sh`](./ec2-asg-alb/user-data.sh)

Replace `<RDS_ENDPOINT>` with your real endpoint before pasting into the console.

Corrected pattern (port **8000**, background process, your RDS host):

```bash
#!/bin/bash
set -euxo pipefail

yum install -y git

cd /home/ec2-user
git clone https://github.com/akhileshmishrabiz/july-devops.git
cd july-devops/week3/src

python3 -m venv .venv
# shellcheck disable=SC1091
source .venv/bin/activate
pip install -r requirements.txt

export DB_LINK="postgresql://admin_user:Admin1234@<RDS_ENDPOINT>:5432/mydb"

# Port 8000 — match target group. /health must return 200.
nohup gunicorn run:app --bind 0.0.0.0:8000 > /var/log/flask-app.log 2>&1 &
```

### Step 3.2: Create launch template

1. EC2 → **Launch templates** → Create
2. Name: e.g. `app-2tier`
3. AMI: Amazon Linux 2023 (recent / patched)
4. Instance type: `t2.nano` / `t3.micro` (lab)
5. Key pair: optional (SSM login comes later)
6. **Security group:** `sg-app` (do this here)
7. Network interfaces: leave unset if you want ASG to own subnets (or follow console guidance)
8. Advanced → **User data:** paste corrected script with real `DB_LINK`
9. Create template

### Step 3.3: Smoke-test from the template (strongly recommended)

1. Launch **one** instance **from the launch template**
2. Place it in a **public** subnet, assign public IP (testing only)
3. Ensure `sg-app` allows **8000** from your IP (temporarily) or from `0.0.0.0/0` for the test
4. Wait 2–3 minutes, then:

```bash
curl -s http://<PUBLIC_IP>:8000/health
# expect: {"status":"healthy","database":"connected"}
```

If it fails:

```bash
ssh …   # or use console
sudo cat /var/log/cloud-init-output.log
sudo tail -100 /var/log/flask-app.log
```

Fix user data / SG / `DB_LINK` / RDS SG, create a **new template version**, set it as **default**, retest. Only then build the ASG.

**Deliverable:** `/health` returns healthy from a template-launched instance.

---

## Part 4 — Target group + ALB (create first)

### Step 4.1: Target group

1. EC2 → **Target groups** → Create
2. Target type: **Instances**
3. Name: e.g. `app-2tier-tg`
4. Protocol: HTTP · **Port: 8000**
5. VPC: July VPC
6. Health checks:
   - Path: **`/health`**
   - Success codes: **200**
7. Do not register targets manually — ASG will register them
8. Create

### Step 4.2: Application Load Balancer

1. EC2 → **Load balancers** → Create → **Application Load Balancer**
2. Scheme: **Internet-facing**
3. VPC: July VPC · map **public-1** and **public-2** (both AZs)
4. Security group: `sg-alb`
5. Listener: HTTP **:80** → forward to `app-2tier-tg`
6. Create

**Deliverable:** ALB DNS name; TG shows no healthy targets yet (expected).

---

## Part 5 — Auto Scaling Group

1. EC2 → **Auto Scaling Groups** → Create
2. Name: e.g. `app-2tier-asg`
3. Launch template: latest/default version (port 8000 user data)
4. Network: July VPC · subnets **private-app-1** and **private-app-2**
5. Load balancing: **Attach existing** → select your ALB target group
6. Health checks: ELB health checks enabled (optional but useful)
7. Group size example:

| Setting | Example |
|---------|---------|
| Desired | 2 |
| Minimum | 1 |
| Maximum | 3 or 4 |

8. Scaling policy (optional): target tracking **CPU ~60%**
9. Create

Confirm:

- Two instances appear, preferably one per AZ (best effort unless you pin)
- Target group → targets become **healthy**
- Browser: `http://<ALB_DNS>/` shows the app (redirect to login is fine for humans)

```bash
curl -sI http://<ALB_DNS>/health
# HTTP/1.1 200
```

**Deliverable:** Healthy targets + app via ALB DNS.

---

## Part 6 — Instance refresh / rolling update (optional)

When you change AMI or user data:

1. New **launch template version** → set **default**
2. ASG → update to that version
3. **Instance refresh**:
   - Prefer **launch before terminate** for low downtime (rolling)
   - Or terminate-first for speed (brief capacity dip)

**Blue/green (concept):** two ASGs + two target groups; switch ALB listener between them. Different from rolling refresh on one ASG.

---

## Part 7 — Domain (optional)

1. Route 53 hosted zone for your domain
2. **A alias** (or CNAME) → ALB DNS name
3. Later: ACM certificate + HTTPS listener :443

Same pattern as Week 2 portfolio DNS, but target is ALB, not Elastic IP.

---

## Part 8 — Short notes

1. Why must ALB subnets be public and app subnets private?
2. Why does private ASG need a **NAT Gateway** for this lab’s user data?
3. Why keep RDS in separate subnets with no internet routes?
4. ALB vs NLB — which for HTTPS web apps, and why (layer)?
5. What does a **target group** do? Why health check `/health` not `/`?
6. Define **RTO** and **RPO**. How does Multi-AZ standby improve them vs snapshot-only?
7. User data vs golden AMI — when is each better?
8. Why attach `sg-app` on the **launch template**, and why RDS allows **5432 from `sg-app` only**?

---

## Submission checklist

- [ ] Public / private-app / private-RDS subnets across **2 AZs**
- [ ] NAT on public subnet; private-app route → NAT
- [ ] RDS private, DB subnet group on RDS subnets, initial DB name set
- [ ] `sg-alb`, `sg-app`, `sg-rds` wired correctly
- [ ] Launch template with corrected user data (`DB_LINK` → RDS, bind **8000**)
- [ ] Smoke test: `/health` healthy from template instance
- [ ] TG port **8000**, health **`/health`** → 200
- [ ] Internet-facing ALB on public subnets → TG
- [ ] ASG in private-app subnets, attached to TG; targets **healthy**
- [ ] App opens via `http://<ALB_DNS>/`
- [ ] Part 8 notes answered

---

## Quick reference

| Item | Value |
|------|--------|
| App bind | `0.0.0.0:8000` |
| Health | `GET /health` → 200 |
| RDS port | 5432 |
| User data file | `ec2-asg-alb/user-data.sh` |
| Cloud-init log | `sudo cat /var/log/cloud-init-output.log` |
| App log (if using nohup) | `sudo tail -f /var/log/flask-app.log` |

`DB_LINK` shape:

```text
postgresql://<user>:<password>@<rds-endpoint>:5432/<db_name>
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Targets never healthy | TG port 80 vs app 8000 | TG port **8000** |
| Health fails on `/` | 301/302 redirect | Path **`/health`**, success **200** |
| User data: git/pip fail on ASG | No NAT / wrong private route | NAT + `0.0.0.0/0` → NAT on app subnets |
| App up but DB errors | RDS SG / wrong `DB_LINK` | Allow 5432 from `sg-app`; fix endpoint/user/db name |
| ALB timeout / 502 | SG: ALB cannot reach :8000 | Inbound 8000 on `sg-app` **from `sg-alb`** |
| Default SG “all traffic” still blocked | Source is **self only** | Explicit rule from `sg-alb` |
| ASG kills instances in a loop | Unhealthy health checks | Fix TG + user data; smoke-test template first |
| Launch template change ignored | Old version still default | New version → set default → instance refresh |

---

## Assignment (before next deep-dive)

1. Read a short overview of **OSI model**, **TCP vs UDP**, and **TLS 1.2 vs 1.3** (YouTube is fine).
2. Compare **ALB vs NLB** in AWS docs — when would you pick NLB?
3. Skim **Docker / containers** intro (next week).

---

## Next class preview

- Finish any remaining ALB/ASG health issues
- **SSM Session Manager** login to private instances (no public IP / no port 22)
- **VPC endpoints** (e.g. S3) vs NAT for private access
- Then: **containers**

Good luck — get healthy targets behind the ALB.
