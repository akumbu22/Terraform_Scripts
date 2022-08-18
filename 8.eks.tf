# Specify the cloud provider

terraform {
 required_providers {
  aws = {
   source = "hashicorp/aws"
  }
 }
}

# Setup an IAM role that has access to the EKS

resource "aws_iam_role" "eks-iam-role" {
 name = "techdom-eks-iam-role"

 path = "/"

 assume_role_policy = <<EOF
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
EOF

}

# Attach the following policies to the IAM role: 
# AmazonEKSClusterPolicy
# AmazonEC2ContainerRegistryReadOnly

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
 policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
 role    = aws_iam_role.eks-iam-role.name
}
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly-EKS" {
 policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
 role    = aws_iam_role.eks-iam-role.name
}


# Create the EKS cluster

resource "aws_eks_cluster" "techdom-eks" {
 name = "techdom-cluster"
 role_arn = aws_iam_role.eks-iam-role.arn

 vpc_config {
  subnet_ids = ["vars.subnet_id_1", "vars.subnet_id_2"]
 }

 depends_on = [
  aws_iam_role.eks-iam-role,
 ]
}


# Set up an IAM role for the worker nodes and attach the following policies: 
# 1. AmazonEKSWorkerNodePolicy
# 2. AmazonEKS_CNI_Policy
# 3. EC2InstanceProfileForImageBuilderECRContainerBuilds
# 4. AmazonEC2ContainerRegistryReadOnly

resource "aws_iam_role" "workernodes" {
  name = "techdom-workernodes"
 
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
 
 resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role    = aws_iam_role.workernodes.name
 }
 
 resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role    = aws_iam_role.workernodes.name
 }
 
 resource "aws_iam_role_policy_attachment" "EC2InstanceProfileForImageBuilderECRContainerBuilds" {
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
  role    = aws_iam_role.workernodes.name
 }
 
 resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role    = aws_iam_role.workernodes.name
 }
 

# Create worker nodes (specify the number under scaling_config)

resource "aws_eks_node_group" "worker-node-group" {
  cluster_name  = aws_eks_cluster.techdom-eks.name
  node_group_name = "techdom-workernodes"
  node_role_arn  = aws_iam_role.workernodes.arn
  subnet_ids   = ["vars.subnet_id_1", "vars.subnet_id_2"]
  instance_types = ["t2.small"]
 
  scaling_config {
   desired_size = 2
   max_size   = 2
   min_size   = 2
  }
 
  depends_on = [
   aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
   aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
   #aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
 }
