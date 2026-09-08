resource "aws_iam_role" "worker_node_role" {
    name = var.role_name

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
            Service = "ec2.amazonaws.com"
            }
        }
        ]
    })

    tags = {
        Name        = var.role_name
        Environment = var.environment
        Owner       = var.owner
    }
}

resource "aws_iam_policy" "ebs_csi_policy" {
    name        = var.policy_name
    description = "Permisos para que el EBS CSI Driver gestione volumenes"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Sid      = "DescribeResources"
            Effect   = "Allow"
            Action   = [
            "ec2:DescribeVolumes",
            "ec2:DescribeInstances",
            "ec2:DescribeSnapshots"
            ]
            Resource = "*"
        },
        {
            Sid      = "ManageEBSVolumes"
            Effect   = "Allow"
            Action   = [
            "ec2:CreateVolume",
            "ec2:DeleteVolume",
            "ec2:AttachVolume",
            "ec2:DetachVolume",
            "ec2:ModifyVolume",
            "ec2:CreateTags"
            ]
            Resource = [
            "arn:aws:ec2:*:*:volume/*",
            "arn:aws:ec2:*:*:instance/*"
            ]
        },
        {
            Sid      = "ManageEBSSnapshots"
            Effect   = "Allow"
            Action   = [
            "ec2:CreateSnapshot",
            "ec2:DeleteSnapshot"
            ]
            Resource = "arn:aws:ec2:*:*:snapshot/*"
        }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_attach" {
    role       = aws_iam_role.worker_node_role.name
    policy_arn = aws_iam_policy.ebs_csi_policy.arn
}

resource "aws_iam_instance_profile" "worker_node_profile" {
    name = var.instance_profile_name
    role = aws_iam_role.worker_node_role.name

    tags = {
        Environment = var.environment
        Owner       = var.owner
    }
}
