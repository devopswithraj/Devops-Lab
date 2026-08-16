# Week 2 — Shell Scripting Assignment

**Bootcamp:** July DevOps  
**Topic:** Bash scripting fundamentals + EC2/nginx automation  
**Repo path:** `week2/shell-scripting/`

---

## Overview

This assignment covers everything from the **Jul 25, 2026** class. You will work through small exercises first, then build the main project: **automate nginx setup on 3 EC2 instances** using the scripts and HTML files in this folder.

**Files in this directory:**

| File | Purpose |
|------|---------|
| `first.sh` | Practice script with commented examples (shebang, args, loops, conditions) |
| `servers.txt` | Public IPs of your 3 EC2 instances (one IP per line) |
| `html/server1.html` | Blue page — served by server 1 |
| `html/server2.html` | Green page — served by server 2 |
| `html/server3.html` | Orange page — served by server 3 |
| `configure-ec2.sh` | Main automation script (install/configure/cleanup nginx) |

**Prerequisites:**

- 3 EC2 instances launched (Amazon Linux), with SSH (port 22) open in the security group
- HTTP (port 80) open if you want to verify nginx in the browser
- Your AWS `.pem` key available locally (e.g. `~/Downloads/july.pem`)
- Basic Linux comfort from Week 1

---

## Part 1 — Script Basics

### Exercise 1.1: Shebang, permissions, and running a script

**Concepts:** shebang (`#!/bin/bash`), file permissions (`rwx`), `chmod`, executing scripts.

1. Open `first.sh` and uncomment only the first active block (lines 13–13 or a simple `echo "Hello World"`).
2. Inspect permissions:
   ```bash
   ls -l first.sh
   ```
3. Run the script three ways:
   ```bash
   bash first.sh
   ./first.sh          # will fail without execute permission
   chmod u+x first.sh  # or: chmod 744 first.sh
   ./first.sh
   ```
4. **Deliverable:** Screenshot or note showing `ls -l` before and after `chmod`, and successful `./first.sh` output.

**Remember from class:**

- `r=4`, `w=2`, `x=1` → `chmod 744` = owner rwx, group r, others r
- `chmod u+x` adds execute for the owner only
- Scripts need **execute (`x`)** permission to run with `./script.sh`

---

### Exercise 1.2: Command-line arguments

**Concepts:** `$0`, `$1`, `$2`, `$@`, `$#`

1. In `first.sh`, uncomment:
   ```bash
   echo "Hello $1 $2"
   echo "Hello $@"
   echo "total number of args: $#"
   ```
2. Run:
   ```bash
   ./first.sh Akhilesh class
   ```
3. **Questions to answer in your notes:**
   - What does `$0` print?
   - What is `$#` when you pass 2 arguments? What about 0 arguments?

---

### Exercise 1.3: Interactive input with `read`

**Concepts:** variables, `read -p`

1. Uncomment in `first.sh`:
   ```bash
   read -p "Enter your name: " name
   echo "Hello $name"
   ```
2. Run `./first.sh` and enter your name when prompted.
3. **Deliverable:** One-line explanation of when you'd use `$1` vs `read -p`.

---

### Exercise 1.4: Conditional logic — file and directory checks

**Concepts:** `if` / `elif` / `else` / `fi`, test operators `-f`, `-d`, `-e`

1. Uncomment the file-exists block in `first.sh` (lines 24–31).
2. Test:
   ```bash
   ./first.sh readme.md      # should say "File exists" if present
   ./first.sh newfile.txt    # should create the file if missing
   ```
3. Uncomment the file **or** directory block (lines 33–46) and test with a filename and a directory name.
4. **Deliverable:** Explain what `-f`, `-d`, and `-e` each check.

---

## Part 2 — Loops

### Exercise 2.1: Fixed `for` loop

1. Uncomment:
   ```bash
   for i in 1 2 3 4 5
   do
       echo $i
   done
   ```
2. Run and confirm output is 1 through 5.

---

### Exercise 2.2: Loop over all command-line arguments

1. Uncomment:
   ```bash
   for i in $@
   do
       echo $i
   done
   ```
2. Run:
   ```bash
   ./first.sh apple banana cherry
   ```

---

### Exercise 2.3: Loop over a file — `servers.txt`

**Concepts:** command substitution `$(cat servers.txt)`, subshell

1. Update `servers.txt` with the **public IPs** of your 3 EC2 instances (one per line).
2. Uncomment in `first.sh`:
   ```bash
   for servers in $(cat servers.txt); do
       echo $servers
   done
   ```
3. Run `./first.sh` and verify all 3 IPs print.
4. **Question:** Why do we use `$(cat servers.txt)` instead of hardcoding IPs in the script?

---

### Exercise 2.4: `while` loop (optional practice)

1. Uncomment the `while` counter loop (lines 67–72) and run it.
2. Uncomment the `while read` loop (lines 75–77), pipe input:
   ```bash
   echo -e "one\ntwo\nthree" | ./first.sh
   ```
3. **Question:** When would a `while read` loop be better than a `for` loop?

---

## Part 3 — SSH Setup (One-Time Manual Steps)

Before automation works, each EC2 instance must trust your SSH key.

### Exercise 3.1: Generate a custom SSH key pair

```bash
ssh-keygen -t rsa -b 2048 -C "your-email@example.com"
# Save to default ~/.ssh/id_rsa (no passphrase for lab use)
```

**Deliverable:** Confirm `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub` exist.

---

### Exercise 3.2: Copy public key to each EC2 instance

Use your AWS `.pem` key the **first time** to authenticate, then copy your new public key:

```bash
chmod 400 ~/Downloads/july.pem   # adjust path to your .pem

ssh-copy-id -i ~/.ssh/id_rsa.pub -o IdentityFile=~/Downloads/july.pem ec2-user@<IP_FROM_servers.txt>
```

Repeat for all 3 IPs in `servers.txt`.

**Verify passwordless login:**

```bash
ssh ec2-user@<IP>
# Should connect without -i or password
exit
```

**Deliverable:** Successful SSH to all 3 servers without specifying `-i`.

**Class note:** After `ssh-copy-id`, your public key lives in `~/.ssh/authorized_keys` on each EC2 instance. Automation scripts can then use SSH/SCP without extra flags.

---

## Part 4 — Remote Commands over SSH

### Exercise 4.1: Run a single remote command

In `configure-ec2.sh`, uncomment:

```bash
for server in $(cat servers.txt)
do
ssh -qT ec2-user@$server hostname
done
```

Run `./configure-ec2.sh` and confirm you see 3 different hostnames.

**Flags explained:**

- `-q` — quiet (less noise)
- `-T` — disable pseudo-terminal; run command and exit

---

### Exercise 4.2: Run multiple remote commands with a heredoc

Uncomment the next block in `configure-ec2.sh`:

```bash
for server in $(cat servers.txt)
do
ssh -qT ec2-user@$server <<EOF
touch a.txt
ls ; date; uptime ; hostname
EOF
done
```

**Deliverable:** Script output showing `ls`, `date`, `uptime`, and `hostname` from each server.

---

## Part 5 — Main Project: Configure Nginx on 3 EC2 Instances

This is the core hands-on from class.

### Goal

For each server in `servers.txt`:

1. Copy a **unique** HTML file (`server1.html`, `server2.html`, `server3.html`)
2. Install nginx
3. Enable nginx on boot
4. Replace default `index.html` with your custom page
5. Start nginx

Each server should show a **different colored page** in the browser (blue / green / orange).

---

### Exercise 5.1: Manual test on ONE server first

Before automating, SSH into **one** EC2 instance and run these commands manually:

```bash
# On your laptop — copy HTML
scp html/server1.html ec2-user@<ONE_IP>:/home/ec2-user/

# On the EC2 instance
sudo yum install nginx -y
sudo systemctl enable nginx
sudo mv /home/ec2-user/server1.html /usr/share/nginx/html/index.html
sudo systemctl start nginx
```

Open `http://<PUBLIC_IP>` in your browser. You should see the blue **Nginx Server 1** page.

**Deliverable:** Browser screenshot of the working page from manual setup.

---

### Exercise 5.2: Automate with `configure-ec2.sh`

Uncomment the main deployment block in `configure-ec2.sh`:

```bash
i=1
for server in $(cat servers.txt)
do
scp html/server$i.html ec2-user@$server:/home/ec2-user/
ssh -qT ec2-user@$server <<EOF

# install nginx
sudo yum install nginx -y
sudo systemctl enable nginx
sudo mv /home/ec2-user/server$i.html /usr/share/nginx/html/index.html
sudo systemctl start nginx

EOF

i=$((i+1))
done
```

**Important details from class:**

- `i=1` must be **outside** the loop (before `for`)
- Use `$i` in `server$i.html` and in the remote `mv` path — not `$1`
- Loop runs once per line in `servers.txt` — it stops after 3 servers even though `i` increments

Make the script executable and run:

```bash
chmod +x configure-ec2.sh
./configure-ec2.sh
```

**Deliverable:**

| Server | Public IP | Expected page |
|--------|-----------|---------------|
| 1 | (your IP) | Blue — "Nginx Server 1" |
| 2 | (your IP) | Green — "Nginx Server 2" |
| 3 | (your IP) | Orange — "Nginx Server 3" |

Screenshot all 3 URLs in the browser.

---

### Exercise 5.3: Cleanup script

The bottom of `configure-ec2.sh` contains a cleanup loop. After testing, run it to remove nginx from all servers:

```bash
# Already active at the bottom of configure-ec2.sh
for server in $(cat servers.txt)
do
ssh -qT ec2-user@$server <<EOF
sudo systemctl stop nginx
sudo systemctl disable nginx
sudo yum remove nginx -y
EOF
done
```

**Deliverable:** Confirm `http://<IP>` no longer loads nginx on all 3 instances.

**Tip:** Comment out the cleanup block and uncomment the deploy block when you want to redeploy.

---

## Part 6 — Stretch Goals (Optional)

### 6.1 Add a `deploy` / `cleanup` argument

Modify `configure-ec2.sh` to accept a command-line argument:

```bash
./configure-ec2.sh deploy    # install and configure nginx
./configure-ec2.sh cleanup   # stop and remove nginx
```

Use `if [ "$1" = "deploy" ]` / `elif [ "$1" = "cleanup" ]`.

---

### 6.2 Error handling

Add a check at the top of `configure-ec2.sh`:

```bash
if [ ! -f servers.txt ]; then
    echo "Error: servers.txt not found"
    exit 1
fi
```

---

### 6.3 Verify nginx is running after deploy

After `systemctl start nginx`, add:

```bash
sudo systemctl is-active nginx
```

Capture or echo the result in the SSH session.

---

## Submission Checklist

- [ ] Part 1: Ran `first.sh` with arguments, `read`, and file/directory conditions
- [ ] Part 2: Looped over `servers.txt` successfully
- [ ] Part 3: Passwordless SSH to all 3 EC2 instances
- [ ] Part 4: Remote `hostname` and multi-command heredoc working
- [ ] Part 5: All 3 servers serving unique HTML via nginx (screenshots)
- [ ] Part 5: Cleanup tested
- [ ] `servers.txt` updated with your real EC2 public IPs
- [ ] Short notes answering the **Questions** in each section

---

## Quick Reference (from class)

| Topic | Syntax / Command |
|-------|------------------|
| Shebang | `#!/bin/bash` |
| Execute permission | `chmod u+x script.sh` |
| Arguments | `$1`, `$2`, `$@`, `$#`, `$0` |
| User input | `read -p "prompt: " var` |
| File exists | `[ -f "$file" ]` |
| Dir exists | `[ -d "$dir" ]` |
| Loop over file lines | `for x in $(cat file.txt); do ... done` |
| Increment counter | `i=$((i+1))` |
| Copy file to remote | `scp localfile user@host:/path/` |
| Remote commands | `ssh -qT user@host <<EOF ... EOF` |
| Install nginx | `sudo yum install nginx -y` |
| Enable on boot | `sudo systemctl enable nginx` |
| Start service | `sudo systemctl start nginx` |
| Default web root | `/usr/share/nginx/html/index.html` |

---

## Troubleshooting

| Problem | Likely fix |
|---------|------------|
| `Permission denied` running `./script.sh` | `chmod u+x script.sh` |
| `Permission denied (publickey)` on SSH | Use `-i your.pem` for first login; run `ssh-copy-id` |
| SCP fails | Check security group allows SSH; verify IP in `servers.txt` |
| Browser shows default nginx page | Confirm `mv` to `/usr/share/nginx/html/index.html` and `systemctl start nginx` |
| Wrong HTML on server 2/3 | Check `$i` is outside loop and used in `server$i.html` |
| Port 80 not reachable | Open HTTP (80) in EC2 security group |

---

## Next Session Preview

Tomorrow's class builds on this: **host a static website with a public IP, DNS name, and HTTPS**. Keep your EC2 instances and nginx knowledge ready.

Good luck — automate first on one server, then scale with the loop.
