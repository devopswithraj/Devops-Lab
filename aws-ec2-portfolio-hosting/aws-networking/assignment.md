# AWS VPC Assignment: Public and Private Subnets

## 🎯 Objective
Create a complete VPC setup with public and private subnets, and learn how to connect to a private EC2 instance through a public bastion host.

## 📋 What You'll Build
- 1 VPC with custom IP range
- 2 Public subnets (in different AZs)
- 2 Private subnets (in different AZs) 
- 1 Internet Gateway for public access
- 1 NAT Gateway for private subnet internet access
- 2 EC2 instances (1 public, 1 private)
- Proper routing and security groups
- SSH access through bastion host

---

## 🚀 Step-by-Step Instructions

### Step 1: Create SSH Key Pair
1. Go to **EC2 Console** → **Key Pairs**
2. Click **Create key pair**
3. Name: `my-vpc-key`
4. Type: **RSA**
5. Format: **.pem**
6. Click **Create key pair**
7. **Download the .pem file** and save it securely

### Step 2: Create VPC
1. Go to **VPC Console** → **Your VPCs**
2. Click **Create VPC**
3. **Settings:**
   - Name: `MyVPC`
   - IPv4 CIDR: `10.0.0.0/16`
   - IPv6 CIDR: No IPv6 CIDR block
   - Tenancy: Default
4. Click **Create VPC**

### Step 3: Create Internet Gateway
1. Go to **Internet Gateways**
2. Click **Create internet gateway**
3. Name: `MyVPC-IGW`
4. Click **Create internet gateway**
5. **Attach to VPC:**
   - Select the IGW → **Actions** → **Attach to VPC**
   - Choose `MyVPC`
   - Click **Attach internet gateway**

### Step 4: Create Subnets

#### Public Subnets:
1. Go to **Subnets** → **Create subnet**
2. **Public Subnet 1:**
   - VPC: `MyVPC`
   - Name: `Public-Subnet-1`
   - AZ: `us-east-1a` (or your region's first AZ)
   - IPv4 CIDR: `10.0.1.0/24`
   
3. **Public Subnet 2:**
   - Name: `Public-Subnet-2`  
   - AZ: `us-east-1b` (different AZ)
   - IPv4 CIDR: `10.0.2.0/24`

#### Private Subnets:
4. **Private Subnet 1:**
   - Name: `Private-Subnet-1`
   - AZ: `us-east-1a`
   - IPv4 CIDR: `10.0.3.0/24`
   
5. **Private Subnet 2:**
   - Name: `Private-Subnet-2`
   - AZ: `us-east-1b`  
   - IPv4 CIDR: `10.0.4.0/24`

### Step 5: Create NAT Gateway
1. Go to **NAT Gateways** → **Create NAT gateway**
2. **Settings:**
   - Name: `MyVPC-NAT`
   - Subnet: `Public-Subnet-1`
   - Connectivity type: **Public**
   - Click **Allocate Elastic IP**
3. Click **Create NAT gateway**

### Step 6: Create Route Tables

#### Public Route Table:
1. Go to **Route Tables** → **Create route table**
2. Name: `Public-RT`
3. VPC: `MyVPC`
4. Click **Create route table**
5. **Add Internet Route:**
   - Select `Public-RT` → **Routes** tab → **Edit routes**
   - Click **Add route**
   - Destination: `0.0.0.0/0`
   - Target: **Internet Gateway** → `MyVPC-IGW`
   - Save changes

#### Private Route Table:
6. Create another route table:
   - Name: `Private-RT`
   - VPC: `MyVPC`
7. **Add NAT Route:**
   - Select `Private-RT` → **Routes** tab → **Edit routes**
   - Click **Add route**
   - Destination: `0.0.0.0/0`
   - Target: **NAT Gateway** → `MyVPC-NAT`
   - Save changes

### Step 7: Associate Subnets with Route Tables

#### Associate Public Subnets:
1. Select `Public-RT` → **Subnet associations** tab
2. Click **Edit subnet associations**
3. Select `Public-Subnet-1` and `Public-Subnet-2`
4. Save associations

#### Associate Private Subnets:
5. Select `Private-RT` → **Subnet associations** tab
6. Click **Edit subnet associations**  
7. Select `Private-Subnet-1` and `Private-Subnet-2`
8. Save associations

### Step 8: Create Security Groups

#### Bastion Host Security Group:
1. Go to **Security Groups** → **Create security group**
2. **Settings:**
   - Name: `Bastion-SG`
   - Description: `SSH access for bastion host`
   - VPC: `MyVPC`
3. **Inbound Rules:**
   - Type: SSH, Port: 22, Source: `Your IP/32` (or `0.0.0.0/0` for testing)
4. **Outbound Rules:** (Keep default - All traffic)

#### Private Instance Security Group:
5. Create another security group:
   - Name: `Private-SG`
   - Description: `Access for private instances`
   - VPC: `MyVPC`
6. **Inbound Rules:**
   - Type: SSH, Port: 22, Source: `Bastion-SG` (select the bastion security group)
   - Type: All ICMP-IPv4, Source: `10.0.0.0/16` (for ping testing)

### Step 9: Launch EC2 Instances

#### Public Instance (Bastion Host):
1. Go to **EC2** → **Launch Instance**
2. **Settings:**
   - Name: `Bastion-Host`
   - AMI: **Amazon Linux 2**
   - Instance type: `t2.micro`
   - Key pair: `my-vpc-key`
   - Network: `MyVPC`
   - Subnet: `Public-Subnet-1`
   - **Auto-assign public IP: Enable**
   - Security group: `Bastion-SG`
3. Launch instance

#### Private Instance:
4. Launch another instance:
   - Name: `Private-Instance`
   - AMI: **Amazon Linux 2**
   - Instance type: `t2.micro`
   - Key pair: `my-vpc-key`
   - Network: `MyVPC`
   - Subnet: `Private-Subnet-1`
   - **Auto-assign public IP: Disable**
   - Security group: `Private-SG`
5. Launch instance

### Step 10: Connect to Instances

#### Step 10.1: Prepare Your SSH Key
```bash
# Set proper permissions on your key file
chmod 400 ~/Downloads/my-vpc-key.pem
```

#### Step 10.2: Connect to Bastion Host
```bash
# Replace with your bastion host's public IP
ssh -i ~/Downloads/my-vpc-key.pem ec2-user@<BASTION_PUBLIC_IP>
```

#### Step 10.3: Copy Key to Bastion Host
```bash
# From your local machine, copy the key to bastion
scp -i ~/Downloads/my-vpc-key.pem ~/Downloads/my-vpc-key.pem ec2-user@<BASTION_PUBLIC_IP>:~/
```

#### Step 10.4: Connect to Private Instance via Bastion
```bash
# SSH into bastion first
ssh -i ~/Downloads/my-vpc-key.pem ec2-user@<BASTION_PUBLIC_IP>

# From bastion, connect to private instance
chmod 400 my-vpc-key.pem
ssh -i my-vpc-key.pem ec2-user@<PRIVATE_INSTANCE_IP>
```

---

## 🧪 Testing Your Setup

### Test Internet Access:
```bash
# On bastion host
ping google.com

# On private instance  
ping google.com  # Should work through NAT
```

### Test Connectivity:
```bash
# From bastion, ping private instance
ping <PRIVATE_INSTANCE_IP>
```

---

## 📊 Network Diagram

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────┐
│                 Internet Gateway                    │
└─────────────────┬───────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────┐
│                   VPC                               │
│               10.0.0.0/16                          │
│                                                     │
│  ┌──────────────────┐    ┌──────────────────┐      │
│  │  Public Subnet 1 │    │  Public Subnet 2 │      │
│  │   10.0.1.0/24   │    │   10.0.2.0/24   │      │
│  │                  │    │                  │      │
│  │ ┌──────────────┐ │    │                  │      │
│  │ │ Bastion Host │ │    │                  │      │
│  │ │  Public IP   │ │    │                  │      │
│  │ └──────────────┘ │    │                  │      │
│  │                  │    │                  │      │
│  │ ┌──────────────┐ │    │                  │      │
│  │ │ NAT Gateway  │ │    │                  │      │
│  │ │  Elastic IP  │ │    │                  │      │
│  │ └──────────────┘ │    │                  │      │
│  └──────────────────┘    └──────────────────┘      │
│           │                                         │
│           ▼ (NAT Route)                             │
│  ┌──────────────────┐    ┌──────────────────┐      │
│  │ Private Subnet 1 │    │ Private Subnet 2 │      │
│  │   10.0.3.0/24   │    │   10.0.4.0/24   │      │
│  │                  │    │                  │      │
│  │ ┌──────────────┐ │    │                  │      │
│  │ │Private Instance│ │    │                  │      │
│  │ │   No Public IP │ │    │                  │      │
│  │ └──────────────┘ │    │                  │      │
│  └──────────────────┘    └──────────────────┘      │
└─────────────────────────────────────────────────────┘
`
**Private instance connecting to Internet using Elastic IP**
`
Your Laptop
    |
    | SSH
    ▼
Bastion Host
(Public subnet)
(Public IP/EIP)
    |
    | SSH using private IP
    ▼
Private EC2
(Private subnet)
    |
    | Internet access
    ▼
NAT Gateway
(Elastic IP)
  |
  ▼
internet
---

## ✅ Verification Checklist

- [✅] VPC created with 10.0.0.0/16 CIDR
- [✅] 2 public subnets in different AZs
- [✅] 2 private subnets in different AZs  
- [✅] Internet Gateway attached to VPC
- [✅] NAT Gateway in public subnet
- [✅] Public route table routes to IGW
- [✅] Private route table routes to NAT
- [✅] Bastion host has public IP
- [✅] Private instance has no public IP
- [✅] Security groups configured properly
- [✅] Can SSH to bastion from internet
- [✅] Can SSH to private instance via bastion
- [✅] Private instance can access internet (ping google.com)

## 🎓 What You Learned

1. **VPC Architecture**: How to design a secure network
2. **Subnetting**: Public vs private subnet concepts  
3. **Routing**: How traffic flows in AWS
4. **NAT Gateway**: How private instances access internet
5. **Security Groups**: Network-level security
6. **Bastion Hosts**: Secure access patterns
7. **SSH Key Management**: Secure connectivity

## 💡 Bonus Challenges

1. **Add an Application Load Balancer** in public subnets
2. **Create a database** in private subnets  
3. **Set up VPC Flow Logs** for monitoring
4. **Configure Network ACLs** for additional security
5. **Use Systems Manager Session Manager** instead of SSH

---

**🎉 Congratulations!** You've built a production-ready VPC architecture!