terraform {
  required_providers {
    aws = {
      version = "3.7.0"
    }
  }

  backend "s3" {}
}

variable "sagemaker_notebook_name" {
  type = string
}

resource "aws_default_vpc" "default" {}

resource "aws_default_subnet" "default_az1" {
  availability_zone = "us-west-2a"
}

resource "aws_iam_role" "sagemaker" {
  name               = "sagemaker_execution_role"
  assume_role_policy = file("${path.module}/sagemaker_assume_role.json")
}

resource "aws_iam_role_policy_attachment" "sagemaker_admin" {
  role       = aws_iam_role.sagemaker.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_security_group" "sagemaker" {
  name = "sagemaker-notebook"

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
}

locals {
  conda_lock_yml = file("${path.module}/../docker-jupyter/conda_lock.yml")

  notebook_on_create = templatefile("${path.module}/notebook_on_create.sh", {
    conda_lock_yml = local.conda_lock_yml
    sagemaker_notebook_name = var.sagemaker_notebook_name
  })

  notebook_on_start = file("${path.module}/notebook_on_start.sh")
}
resource "aws_sagemaker_notebook_instance_lifecycle_configuration" "ucla_deeplearning" {
  name      = "ucla-deep-learning-conda-env"
  on_create = base64encode(local.notebook_on_create)
  on_start = base64encode(local.notebook_on_start)
}

resource "aws_dynamodb_table" "table" {
  name = "ucla-deep-learning-notebooks"
  billing_mode = "PAY_PER_REQUEST"
  attribute {
    name = "name"
    type = "S"
  }
  hash_key = "name"
}

output "sagemaker_lifecycle_name" {
  value = aws_sagemaker_notebook_instance_lifecycle_configuration.ucla_deeplearning.name
}

output "subnet_id" {
  value = aws_default_subnet.default_az1.id
}

output "security_group_id" {
  value = aws_security_group.sagemaker.id
}

output "role_arn" {
  value = aws_iam_role.sagemaker.arn
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.table.name
}