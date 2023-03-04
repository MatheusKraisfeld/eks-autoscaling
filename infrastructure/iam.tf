resource "aws_iam_policy" "eks_autoscaler_policy" {
  name        = "AmazonEKSClusterAutoscalerPolicy"
  path        = "/"
  description = "Amazon EKS Cluster Autoscaler Policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "aws:ResourceTag/k8s.io/cluster-autoscaler/eks-autoscaling": "owned"
                }
            }
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeAutoScalingGroups",
                "ec2:DescribeLaunchTemplateVersions",
                "autoscaling:DescribeTags",
                "autoscaling:DescribeLaunchConfigurations",
                "ec2:DescribeInstanceTypes"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

# resource "aws_iam_role" "eks_autoscaler_role" {
#   name = "AmazonEKSClusterAutoscalerRole"

#   assume_role_policy = <<EOF
# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Effect": "Allow",
#             "Action": "sts:AssumeRoleWithWebIdentity",
#             "Principal": {
#                 "Federated": "arn:aws:iam::741358071637:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
#             },
#             "Condition": {
#                 "StringEquals": {
#                     "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub": [
#                         "system:serviceaccount:kube-system:cluster-autoscaler"
#                     ]
#                 }
#             }
#         }
#     ]
# }
# EOF
# }