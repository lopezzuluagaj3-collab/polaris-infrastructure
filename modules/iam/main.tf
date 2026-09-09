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
    name        = "polaris-ec2-ebs-policy"   # <- nombre original, evita el replace
    description = "Permisos para que el EBS CSI Driver gestione volumenes"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Sid    = "DescribeResources"
            Effect = "Allow"
            Action = [
            "ec2:DescribeVolumes",
            "ec2:DescribeInstances",
            "ec2:DescribeSnapshots",
            "ec2:DescribeAvailabilityZones"
            ]
            Resource = "*"
        },
        {
            Sid    = "ManageEBSVolumes"
            Effect = "Allow"
            Action = [
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
            Sid    = "ManageEBSSnapshots"
            Effect = "Allow"
            Action = [
            "ec2:CreateSnapshot",
            "ec2:DeleteSnapshot"
            ]
            Resource = "arn:aws:ec2:*:*:snapshot/*"
        }
        ]
    })
    }

# Elimina o comenta este bloque - es redundante, el usuario ya recibe
# los permisos vía membresía al grupo (aws_iam_user_group_membership)
# resource "aws_iam_user_policy_attachment" "ebs_csi_user_attach" {
#   user       = aws_iam_user.ebs_csi_user.name
#   policy_arn = aws_iam_policy.ebs_csi_policy.arn
# }



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





resource "aws_iam_group" "ebs_csi_group" {
    name = "polaris-ec2-group"
}

resource "aws_iam_user" "ebs_csi_user" {
    #checkov:skip=CKV_AWS_273:project requires IAM user
    name = var.user_name

    tags = {
        Environment = var.environment
        Owner       = var.owner
    }
}

resource "aws_iam_group_policy_attachment" "ebs_csi_group_attach" {
    group      = aws_iam_group.ebs_csi_group.name
    policy_arn = aws_iam_policy.ebs_csi_policy.arn
}

resource "aws_iam_user_group_membership" "ebs_csi_membership" {
    user = aws_iam_user.ebs_csi_user.name
    groups = [
        aws_iam_group.ebs_csi_group.name
    ]
}

resource "aws_iam_access_key" "ebs_csi_key" {
    user = aws_iam_user.ebs_csi_user.name
}

