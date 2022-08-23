## Firstly, ensure that "AdministratorAccess" policy is assigned to the Terraform role.

# Step 1- Specify the cloud provider
#===================================

provider "aws" {
  region = "us-east-1"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}


# Step 2 - Create a VPC
#======================

resource "aws_vpc" "techdomvpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "techdomvpc"
  }
}

# Step 3 - Create an Internet Gateway
#====================================

resource "aws_internet_gateway" "techdomigw" {
  vpc_id = aws_vpc.techdomvpc.id

  tags = {
    Name = "techdomigw"
  }
}

# Step 4 - Create subnets
#========================

resource "aws_subnet" "private-us-east-1a" {
  vpc_id            = aws_vpc.techdomvpc.id
  cidr_block        = "10.0.0.0/19"
  availability_zone = "us-east-1a"

  tags = {
    "Name"                                      = "private-us-east-1a"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/techdomcluster"      = "owned"
  }
}

resource "aws_subnet" "private-us-east-1b" {
  vpc_id            = aws_vpc.techdomvpc.id
  cidr_block        = "10.0.32.0/19"
  availability_zone = "us-east-1b"

  tags = {
    "Name"                                      = "private-us-east-1b"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/techdomcluster"      = "owned"
  }
}

resource "aws_subnet" "public-us-east-1a" {
  vpc_id                  = aws_vpc.techdomvpc.id
  cidr_block              = "10.0.64.0/19"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    "Name"                                 = "public-us-east-1a"
    "kubernetes.io/role/elb"               = "1"
    "kubernetes.io/cluster/techdomcluster" = "owned"
  }
}

resource "aws_subnet" "public-us-east-1b" {
  vpc_id                  = aws_vpc.techdomvpc.id
  cidr_block              = "10.0.96.0/19"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    "Name"                                 = "public-us-east-1b"
    "kubernetes.io/role/elb"               = "1"
    "kubernetes.io/cluster/techdomcluster" = "owned"
  }
}


# Step 5 - Create NAT (Network Address Translation) Gateway
#==========================================================
# Understanding NAT Gateway- https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html

resource "aws_eip" "techdomnat" {
  vpc = true

  tags = {
    Name = "techdomnat"
  }
}

resource "aws_nat_gateway" "techdomnat" {
  allocation_id = aws_eip.techdomnat.id
  subnet_id     = aws_subnet.public-us-east-1a.id

  tags = {
    Name = "techdomnat"
  }

  depends_on = [aws_internet_gateway.techdomigw]
}


# Step 6 - Create Route Tables and Associate them with the Subnets
#=================================================================

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.techdomvpc.id

  route = [
    {
      cidr_block                 = "0.0.0.0/0"
      nat_gateway_id             = aws_nat_gateway.techdomnat.id
      carrier_gateway_id         = ""
      destination_prefix_list_id = ""
      egress_only_gateway_id     = ""
      gateway_id                 = ""
      instance_id                = ""
      ipv6_cidr_block            = ""
      local_gateway_id           = ""
      network_interface_id       = ""
      transit_gateway_id         = ""
      vpc_endpoint_id            = ""
      vpc_peering_connection_id  = ""
    },
  ]

  tags = {
    Name = "private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.techdomvpc.id

  route = [
    {
      cidr_block                 = "0.0.0.0/0"
      gateway_id                 = aws_internet_gateway.techdomigw.id
      nat_gateway_id             = ""
      carrier_gateway_id         = ""
      destination_prefix_list_id = ""
      egress_only_gateway_id     = ""
      instance_id                = ""
      ipv6_cidr_block            = ""
      local_gateway_id           = ""
      network_interface_id       = ""
      transit_gateway_id         = ""
      vpc_endpoint_id            = ""
      vpc_peering_connection_id  = ""
    },
  ]

  tags = {
    Name = "public"
  }
}

resource "aws_route_table_association" "private-us-east-1a" {
  subnet_id      = aws_subnet.private-us-east-1a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private-us-east-1b" {
  subnet_id      = aws_subnet.private-us-east-1b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public-us-east-1a" {
  subnet_id      = aws_subnet.public-us-east-1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public-us-east-1b" {
  subnet_id      = aws_subnet.public-us-east-1b.id
  route_table_id = aws_route_table.public.id
}


# Step 7 - Create IAM Role for the Cluster, Attach Policy to Role, and Create a Cluster
#======================================================================================

resource "aws_iam_role" "techdomclusterrole" {
  name = "techdomclusterrole"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "techdomclusterrole-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.techdomclusterrole.name
}

resource "aws_eks_cluster" "techdomcluster" {
  name     = "techdomcluster"
  role_arn = aws_iam_role.techdomclusterrole.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.private-us-east-1a.id,
      aws_subnet.private-us-east-1b.id,
      aws_subnet.public-us-east-1a.id,
      aws_subnet.public-us-east-1b.id
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.techdomclusterrole-AmazonEKSClusterPolicy]
}


# Step 8 - Create IAM Role for the Worker Nodes, Attach Policies to Role, and Create Worker Nodes 
#================================================================================================

resource "aws_iam_role" "techdomnoderole" {
  name = "techdomnodes"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "techdomnoderole-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.techdomnoderole.name
}

resource "aws_iam_role_policy_attachment" "techdomnoderole-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.techdomnoderole.name
}

resource "aws_iam_role_policy_attachment" "techdomnoderole-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.techdomnoderole.name
}

resource "aws_eks_node_group" "techdomnodes" {
  cluster_name    = aws_eks_cluster.techdomcluster.name
  node_group_name = "techdomnodes"
  node_role_arn   = aws_iam_role.techdomnoderole.arn

  subnet_ids = [
    aws_subnet.private-us-east-1a.id,
    aws_subnet.private-us-east-1b.id
  ]

  capacity_type  = "ON_DEMAND"
  instance_types = ["t2.micro"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 2
  }

  labels = {
    role = "general"
  }

  # taint {
  #   key    = "team"
  #   value  = "devops"
  #   effect = "NO_SCHEDULE"
  # }

  # launch_template {
  #   name    = aws_launch_template.eks-with-disks.name
  #   version = aws_launch_template.eks-with-disks.latest_version
  # }

  depends_on = [
    aws_iam_role_policy_attachment.techdomnoderole-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.techdomnoderole-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.techdomnoderole-AmazonEC2ContainerRegistryReadOnly,
  ]
}

# resource "aws_launch_template" "eks-with-disks" {
#   name = "eks-with-disks"

#   key_name = "local-provisioner"

#   block_device_mappings {
#     device_name = "/dev/xvdb"

#     ebs {
#       volume_size = 50
#       volume_type = "gp2"
#     }
#   }
# }

# Step 9 - Create an Open ID Connection for the Cluster
#======================================================

data "tls_certificate" "techdomeks" {
  url = aws_eks_cluster.techdomcluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "techdomeks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.techdomeks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.techdomcluster.identity[0].oidc[0].issuer
}  


# Step 10 - Create IAM Role for the Open-ID Connection, and Attach Policy to Role
#================================================================================

data "aws_iam_policy_document" "techdom_oidc_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.techdomeks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:default:aws-techdom"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.techdomeks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "techdom_oidc" {
  assume_role_policy = data.aws_iam_policy_document.techdom_oidc_assume_role_policy.json
  name               = "techdom-oidc"
}

resource "aws_iam_policy" "techdom-policy" {
  name = "techdom-policy"

  policy = jsonencode({
    Statement = [{
      Action = [
        "s3:ListAllMyBuckets",
        "s3:GetBucketLocation"
      ]
      Effect   = "Allow"
      Resource = "arn:aws:s3:::*"
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "test_attach" {
  role       = aws_iam_role.techdom_oidc.name
  policy_arn = aws_iam_policy.techdom-policy.arn
}

output "test_policy_arn" {
  value = aws_iam_role.techdom_oidc.arn
}


# Step 11 - Create IAM Role for Autoscaler, and Attach Policy to Role
#====================================================================

data "aws_iam_policy_document" "eks_cluster_autoscaler_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.techdomeks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.techdomeks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "eks_cluster_autoscaler" {
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_autoscaler_assume_role_policy.json
  name               = "eks-cluster-autoscaler"
}

resource "aws_iam_policy" "eks_cluster_autoscaler" {
  name = "eks-cluster-autoscaler"

  policy = jsonencode({
    Statement = [{
      Action = [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeLaunchTemplateVersions"
            ]
      Effect   = "Allow"
      Resource = "*"
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_autoscaler_attach" {
  role       = aws_iam_role.eks_cluster_autoscaler.name
  policy_arn = aws_iam_policy.eks_cluster_autoscaler.arn
}

output "eks_cluster_autoscaler_arn" {
  value = aws_iam_role.eks_cluster_autoscaler.arn
}
