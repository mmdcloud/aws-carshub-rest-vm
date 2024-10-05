# CodeDeploy Configuration
data "aws_iam_policy_document" "codedeploy_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codedeploy_iam_role" {
  name               = "codedeploy-role"
  assume_role_policy = data.aws_iam_policy_document.codedeploy_assume_role.json
}

resource "aws_iam_role_policy_attachment" "codedeploy_role_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.codedeploy_iam_role.name
}

resource "aws_codedeploy_app" "nodeapp_deploy" {
  compute_platform = "Server"
  name             = "nodeapp-deploy"
}

resource "aws_codedeploy_deployment_group" "codedeploy_dg" {
  app_name              = aws_codedeploy_app.nodeapp_deploy.name
  deployment_group_name = "nodeapp-dg"
  service_role_arn      = aws_iam_role.codedeploy_iam_role.arn

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
  autoscaling_groups = [aws_autoscaling_group.asg.name]
  # outdated_instances_strategy = "UPDATE"
}