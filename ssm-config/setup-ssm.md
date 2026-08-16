# SSM Session Manager — Simple Setup

### 1. Create VPC Endpoints

In **VPC → Endpoints → Create endpoint**, create these **Interface** endpoints in `ap-south-1`:

```text
com.amazonaws.ap-south-1.ssm
com.amazonaws.ap-south-1.ssmmessages
com.amazonaws.ap-south-1.ec2messages
```

For each endpoint:

* Select your VPC
* Select the private subnet
* Enable **Private DNS**
* Attach a security group allowing **TCP 443 from the EC2 security group**

### 2. Create IAM Role

Create an EC2 IAM role and attach:

```text
AmazonSSMManagedInstanceCore
```

Attach this role to your EC2 instance.

### 3. Check SSM Agent

On the EC2:

```bash
sudo systemctl enable --now amazon-ssm-agent
```

Check:

```bash
sudo systemctl status amazon-ssm-agent
```

### 4. Check EC2 Security Group

Allow outbound:

```text
TCP 443
```

No inbound port `22` is required.

### 5. Check the Instance

Go to:

**AWS Console → Systems Manager → Fleet Manager → Managed nodes**

Your EC2 should show **Online**.

### 6. Login

Go to:

**Systems Manager → Session Manager → Start session → Select EC2 → Start session**

That's it. The EC2 can stay **private with no public IP and no SSH access**.
