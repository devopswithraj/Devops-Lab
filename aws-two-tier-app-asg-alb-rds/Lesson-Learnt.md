# AWS 2-Tier Application: EC2, RDS, Security Groups, User Data, and Connectivity

## 1. Architecture

The application has two main tiers:

```text
                  Internet
                     |
                     | HTTP :8000
                     v
              EC2 Public IP
                     |
                     | Flask/Gunicorn :8000
                     |
                  EC2
                     |
                     | PostgreSQL :5432
                     |
                     v
              RDS PostgreSQL
              Private IP
```

For the final production-style architecture, an Application Load Balancer (ALB) should sit in front of the EC2 instances:

```text
Internet
   |
   v
ALB
   |
   | :8000
   v
EC2 / ASG
   |
   | :5432
   v
RDS PostgreSQL
```

---

# 2. Public IP vs Private IP

One of the most important concepts learned from this exercise is that the public IP and private IP serve different purposes.

### Browser → EC2

When testing from a browser:

```text
http://<EC2_PUBLIC_IP>:8000/health
```

The browser reaches the EC2 instance through its public IP.

### EC2 → RDS

The application does NOT need to connect to RDS using a public IP.

The application uses the RDS endpoint:

```text
mydb.xxxxx.us-east-1.rds.amazonaws.com
```

DNS resolves this to a private IP such as:

```text
10.0.3.187
```

Therefore:

```text
EC2 private network
       |
       | TCP 5432
       v
RDS private IP
10.0.3.187
```

This is the preferred architecture.

---

# 3. Why Test localhost?

There are two different tests.

## Test 1: Application test

From inside EC2:

```bash
curl -i http://localhost:8000/health
```

This tests:

```text
EC2
 |
 +-- Gunicorn :8000
```

It answers:

> Is my Flask/Gunicorn application running?

If this fails, investigate the application.

---

## Test 2: Network accessibility test

From your laptop:

```text
http://<EC2_PUBLIC_IP>:8000/health
```

This tests:

```text
Laptop
  |
  | Internet
  v
EC2 Public IP
  |
  v
Gunicorn :8000
```

It answers:

> Can external traffic reach my application?

Therefore localhost and public IP tests have different purposes.

---

# 4. What Happened During This Exercise?

Initially, Gunicorn appeared not to be running.

The cloud-init log showed:

```text
psycopg2.OperationalError:
connection to server at "mydb.xxxxx.rds.amazonaws.com"
port 5432 failed:
Connection timed out
```

This was the important error.

The application was trying to connect to PostgreSQL, but the connection to RDS timed out.

The problem was therefore not necessarily Gunicorn itself.

The actual problem was:

```text
EC2  ----X----> RDS :5432
```

---

# 5. How the Problem Was Diagnosed

The following command was used:

```bash
sudo grep -iE "error|failed|traceback" /var/log/cloud-init-output.log
```

This exposed the PostgreSQL connection error.

The error showed:

```text
connection to server ... port 5432 failed:
Connection timed out
```

This tells us:

* DNS resolution worked.
* The RDS endpoint was reachable enough to resolve to an IP.
* But TCP connection to port 5432 was blocked or unreachable.

---

# 6. Security Groups

The key security-group relationship should be:

```text
EC2
sg-app
 |
 | TCP 5432
 v
RDS
sg-db
```

The RDS security group should allow:

```text
Type: PostgreSQL
Port: 5432
Source: sg-app
```

Using the EC2 security group as the source is better than allowing:

```text
0.0.0.0/0
```

because it limits database access to resources associated with `sg-app`.

---

# 7. Verifying Database Connectivity

After fixing the security-group rule, the following test was successful:

```bash
nc -vz mydb.xxxxx.us-east-1.rds.amazonaws.com 5432
```

Output:

```text
Ncat: Connected to 10.0.3.187:5432.
```

This proved:

```text
EC2
 |
 | TCP 5432
 v
10.0.3.187
RDS
```

was working.

The message:

```text
0 bytes sent, 0 bytes received
```

is normal for an `nc` connectivity test. The important part is:

```text
Connected
```

---

# 8. User Data and Cloud-Init

EC2 user data runs during the initial instance boot.

The script was:

```bash
#!/bin/bash
set -euxo pipefail

yum install -y git

cd /home/ec2-user
git clone https://github.com/akhileshmishrabiz/july-devops.git
cd july-devops/week3/src

python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

export DB_LINK='postgresql://admin_user:PASSWORD@RDS_ENDPOINT:5432/mydb'

nohup gunicorn run:app \
  --bind 0.0.0.0:8000 \
  > /var/log/flask-app.log 2>&1 &
```

The important point is that user data is executed automatically when the instance is launched.

---

# 9. Why User Data Appeared to Fail

The user-data script did not necessarily have a Gunicorn installation problem.

The application eventually attempted to connect to RDS.

Because RDS connectivity was initially blocked, the application produced:

```text
psycopg2.OperationalError
```

and SQLAlchemy reported:

```text
sqlalchemy.exc.OperationalError
```

Therefore, when debugging user data, do not assume:

```text
Gunicorn not running
       =
Gunicorn installation problem
```

Instead check the complete boot sequence.

---

# 10. Important Cloud-Init Logs

The main log for user-data troubleshooting is:

```bash
sudo cat /var/log/cloud-init-output.log
```

Or:

```bash
sudo tail -200 /var/log/cloud-init-output.log
```

You can search for errors:

```bash
sudo grep -iE "error|failed|traceback" \
  /var/log/cloud-init-output.log
```

Another useful file is:

```bash
sudo cat /var/log/cloud-init.log
```

The user-data that EC2 actually received can also be inspected:

```bash
sudo cat /var/lib/cloud/instance/user-data.txt
```

This is useful when troubleshooting launch-template version problems.

---

# 11. Launch Template Version Matters

If you modify the user data in a launch template, make sure the new instance is launched using the correct launch-template version.

For example:

```text
Launch Template
      |
      +-- Version 1  ← old user data
      |
      +-- Version 2  ← corrected user data
```

If the instance is launched using Version 1, changing Version 2 will not change the existing instance.

For a clean test:

1. Create a new launch-template version.
2. Put the corrected user data in it.
3. Launch a new instance using that version.
4. Wait for cloud-init.
5. Check the cloud-init logs.
6. Test the application.

---

# 12. Testing Checklist

After launching a new EC2 instance:

### Step 1 — Check user data

```bash
sudo tail -200 /var/log/cloud-init-output.log
```

### Step 2 — Check Gunicorn

```bash
ps aux | grep gunicorn
```

### Step 3 — Check port 8000

```bash
sudo ss -lntp | grep 8000
```

Expected:

```text
0.0.0.0:8000
```

### Step 4 — Test application locally

```bash
curl -i http://localhost:8000/health
```

Expected:

```text
HTTP/1.1 200 OK
```

### Step 5 — Test RDS connectivity

```bash
nc -vz RDS_ENDPOINT 5432
```

Expected:

```text
Connected
```

### Step 6 — Test externally

From your laptop:

```text
http://EC2_PUBLIC_IP:8000/health
```

---

# 13. Troubleshooting Decision Tree

```text
EC2 launched
     |
     v
Did user data run?
     |
     +-- NO --> Check cloud-init logs
     |
     +-- YES
          |
          v
Is Gunicorn installed?
          |
          +-- NO --> Check pip/requirements
          |
          +-- YES
               |
               v
Does Gunicorn start?
               |
               +-- NO --> Check run:app / Python errors
               |
               +-- YES
                    |
                    v
localhost:8000/health
                    |
                    +-- FAIL --> Application/database problem
                    |
                    +-- 200
                         |
                         v
              EC2_PUBLIC_IP:8000
                         |
                         +-- FAIL --> EC2 SG/network problem
                         |
                         +-- 200
                              |
                              v
                         Application works
```

---

# 14. Security Group Model to Remember

For the final architecture, think in terms of **who is allowed to talk to whom**.

```text
Internet
   |
   | HTTP/HTTPS
   v
ALB
   |
   | TCP 8000
   v
EC2 / sg-app
   |
   | TCP 5432
   v
RDS / sg-db
```

Security rules:

```text
ALB SG
  |
  +--> EC2 SG : 8000

EC2 SG
  |
  +--> RDS SG : 5432
```

This is much safer than opening everything to the Internet.

---

# 15. Key Lessons Learned

## Lesson 1 — A timeout is different from an application error

```text
Connection timed out
```

usually points toward:

* Security groups
* Network ACLs
* Routing
* Network connectivity
* Firewall rules

It is different from:

```text
Connection refused
```

which can indicate that nothing is listening on the destination port.

---

## Lesson 2 — Test layer by layer

Do not immediately test everything through the browser.

Test:

```text
Application
    ↓
localhost
    ↓
EC2 networking
    ↓
RDS networking
    ↓
ALB
    ↓
Internet
```

This makes troubleshooting much easier.

---

## Lesson 3 — RDS should normally remain private

The application should communicate with RDS through the private VPC network.

Do not make PostgreSQL publicly accessible just because the application is publicly accessible.

```text
Public:
ALB / temporary EC2 testing

Private:
RDS
```

---

## Lesson 4 — Security groups are stateful

If EC2 is allowed to connect to RDS on TCP 5432 and RDS allows the connection from the EC2 security group, return traffic is automatically allowed by the stateful security group behavior.

---

## Lesson 5 — User-data debugging starts with cloud-init logs

When an EC2 bootstrap script doesn't behave as expected, check:

```bash
sudo tail -200 /var/log/cloud-init-output.log
```

before assuming the application itself is broken.

---

# 16. Final Mental Model

The most important concept from this exercise is:

```text
                PUBLIC
                  |
                  v
             Your Browser
                  |
                  | EC2 Public IP
                  v
             +----------+
             |   EC2    |
             | Gunicorn |
             |  :8000   |
             +----------+
                  |
                  | Private VPC network
                  | PostgreSQL :5432
                  v
             +----------+
             |   RDS    |
             | Private  |
             |  :5432   |
             +----------+
```

The **browser uses the public path** to reach the application.

The **application uses the private path** to reach RDS.

That separation is the foundation of a typical AWS 2-tier architecture.

AWS ALB & EC2 Health Check Troubleshooting:

Application and database were working correctly: Gunicorn was listening on 0.0.0.0:8000, /health returned 200 OK, and the application successfully connected to RDS on port 5432.

ALB target was unhealthy because of the health-check port: The target group's traffic port was correctly set to 8000, but the health-check port was set to 80. The ALB was therefore checking EC2:80 instead of EC2:8000, resulting in Request timed out.

Fix and key learning: Changed Health check port → Traffic port, with path /health and success code 200. The targets became Healthy. The key learning is that target traffic port and health-check port are separate settings.