# EC2 IAM Instance Profile
data "aws_iam_policy_document" "instance_profile_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "instance_profile_iam_role" {
  name               = "instance-profile-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.instance_profile_assume_role.json
}

data "aws_iam_policy_document" "instance_profile_policy_document" {
  statement {
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "instance_profile_s3_policy" {
  role   = aws_iam_role.instance_profile_iam_role.name
  policy = data.aws_iam_policy_document.instance_profile_policy_document.json
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "iam-instance-profile"
  role = aws_iam_role.instance_profile_iam_role.name
}

resource "aws_launch_template" "nodejs_template" {
  name = "nodejs_template"

  description = "Sample Node.js App !"

  image_id = "ami-0e86e20dae9224db8"

  instance_type = "t2.micro"

  key_name = "mohit"

  ebs_optimized = false

  iam_instance_profile {
    name = aws_iam_instance_profile.iam_instance_profile.name
  }

  instance_initiated_shutdown_behavior = "stop"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.asg.id]
  }
  user_data = base64encode(templatefile("${path.module}/scripts/user_data.sh", {
    db_path  = tostring(split(":", aws_db_instance.carshub-db.endpoint)[0])
    username = tostring(data.vault_generic_secret.rds.data["username"])
    password = tostring(data.vault_generic_secret.rds.data["password"])
  }))

  depends_on = [aws_db_instance.carshub-db]
}
