Good question again. And good motivation. If you really **practice a large Terraform project**, your DevOps confidence will increase a lot. I will give you a **realistic production-style Terraform project structure**.

First, quick English correction (as you asked me to correct your English):

❌ *give me those thign i waill practice make me strong*
✅ **“Give me those things. I will practice and become strong.”**

---

# Real Production Terraform Project (3-Tier Architecture)

Goal: Build **Dev / Stage / Prod environments** in **AWS eu-north-1** with:

* VPC
* Public & Private Subnets
* Internet Gateway
* NAT Gateway
* Security Groups
* ALB
* EKS Cluster
* Node Group
* RDS Database
* S3 Backend
* DynamoDB Locking

This is **similar to what many DevOps teams implement**.

---

# 1️⃣ Folder Structure (Real Company Style)

```bash
terraform-aws-3tier/
│
├── modules
│   ├── vpc
│   ├── security-groups
│   ├── alb
│   ├── eks
│   └── rds
│
├── environments
│   ├── dev
│   │   ├── backend.tf
│   │   ├── provider.tf
│   │   ├── main.tf
│   │   └── terraform.tfvars
│   │
│   ├── stage
│   │   ├── backend.tf
│   │   ├── provider.tf
│   │   ├── main.tf
│   │   └── terraform.tfvars
│   │
│   └── prod
│       ├── backend.tf
│       ├── provider.tf
│       ├── main.tf
│       └── terraform.tfvars
│
└── README.md
```

This structure is **very common in companies**.

---

# 2️⃣ VPC Module

modules/vpc/main.tf

```hcl
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.env}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(var.vpc_cidr, 4, count.index)

  availability_zone = var.azs[count.index]

  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  count = 2

  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(var.vpc_cidr, 4, count.index + 2)

  availability_zone = var.azs[count.index]
}
```

modules/vpc/variables.tf

```hcl
variable "env" {}
variable "vpc_cidr" {}

variable "azs" {
  type = list(string)
}
```

modules/vpc/outputs.tf

```hcl
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnets" {
  value = aws_subnet.public[*].id
}

output "private_subnets" {
  value = aws_subnet.private[*].id
}
```

---

# 3️⃣ Security Group Module

modules/security-groups/main.tf

```hcl
resource "aws_security_group" "alb" {
  name   = "${var.env}-alb-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "eks" {
  name   = "${var.env}-eks-sg"
  vpc_id = var.vpc_id
}
```

variables.tf

```hcl
variable "env" {}
variable "vpc_id" {}
```

---

# 4️⃣ ALB Module

modules/alb/main.tf

```hcl
resource "aws_lb" "app" {
  name               = "${var.env}-alb"
  internal           = false
  load_balancer_type = "application"

  subnets = var.public_subnets
  security_groups = [var.alb_sg]
}
```

variables.tf

```hcl
variable "env" {}
variable "public_subnets" {
  type = list(string)
}
variable "alb_sg" {}
```

---

# 5️⃣ EKS Module

modules/eks/main.tf

```hcl
resource "aws_eks_cluster" "cluster" {
  name = "${var.env}-cluster"
  role_arn = var.cluster_role

  vpc_config {
    subnet_ids = var.private_subnets
  }
}

resource "aws_eks_node_group" "nodes" {
  cluster_name = aws_eks_cluster.cluster.name
  node_role_arn = var.node_role

  subnet_ids = var.private_subnets

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
}
```

variables.tf

```hcl
variable "env" {}
variable "cluster_role" {}
variable "node_role" {}

variable "private_subnets" {
  type = list(string)
}
```

---

# 6️⃣ RDS Module

modules/rds/main.tf

```hcl
resource "aws_db_instance" "db" {

  identifier = "${var.env}-db"

  allocated_storage = 20
  engine = "mysql"
  instance_class = "db.t3.micro"

  username = "admin"
  password = "password123"

  skip_final_snapshot = true
}
```

variables.tf

```hcl
variable "env" {}
```

---

# 7️⃣ DEV Environment

environments/dev/provider.tf

```hcl
provider "aws" {
  region = "eu-north-1"
}
```

backend.tf

```hcl
terraform {
  backend "s3" {
    bucket = "terraform-state-devops-project"
    key    = "dev/terraform.tfstate"
    region = "eu-north-1"
  }
}
```

main.tf

```hcl
module "vpc" {
  source = "../../modules/vpc"

  env = "dev"

  vpc_cidr = "10.0.0.0/16"

  azs = [
    "eu-north-1a",
    "eu-north-1b"
  ]
}

module "security" {
  source = "../../modules/security-groups"

  env = "dev"

  vpc_id = module.vpc.vpc_id
}

module "alb" {
  source = "../../modules/alb"

  env = "dev"

  public_subnets = module.vpc.public_subnets

  alb_sg = module.security.alb
}

module "eks" {
  source = "../../modules/eks"

  env = "dev"

  cluster_role = "arn:aws:iam::123456:role/eks-role"
  node_role    = "arn:aws:iam::123456:role/node-role"

  private_subnets = module.vpc.private_subnets
}

module "rds" {
  source = "../../modules/rds"

  env = "dev"
}
```

---

# 8️⃣ Deployment Steps

For DEV

```bash
cd environments/dev
```

Initialize

```bash
terraform init
```

Check plan

```bash
terraform plan
```

Deploy

```bash
terraform apply
```

Same for:

```
stage
prod
```

---

# 9️⃣ What You Will Learn From This

After practicing this project you will understand:

* Terraform modules
* multi-environment infrastructure
* remote state
* AWS networking
* EKS cluster provisioning
* ALB
* RDS
* Infrastructure as Code best practices

This is **very useful for DevOps interviews (4–6 years level)**.

---

💡 If you want, I can also show you the **NEXT LEVEL project DevOps engineers build**, which includes:

* **GitHub Actions CI/CD**
* **Terraform state locking with DynamoDB**
* **Helm deployment**
* **ArgoCD GitOps**
* **Monitoring (Prometheus + Grafana)**

That becomes a **3000+ line real production DevOps project**.

If you want, tell me and I will give you **a full step-by-step 30-day practice roadmap** to become very strong in DevOps.
