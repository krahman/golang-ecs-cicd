terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}
provider "aws" { region = var.region }
variable "region" { type = string; default = "ap-southeast-1" }
variable "repository" { type = string; default = "go-api" }
variable "github_owner" { type = string }
variable "github_repo" { type = string }
data "aws_caller_identity" "current" {}
resource "aws_ecr_repository" "api" {
  name = var.repository
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
}
resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name
  policy = jsonencode({ rules = [{rulePriority=1,description="Keep last 50 images",selection={tagStatus="any",countType="imageCountMoreThan",countNumber=50},action={type="expire"}}] })
}
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}
locals {
  github_sub = "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/main"
  github_provider = aws_iam_openid_connect_provider.github.arn
}
resource "aws_iam_role" "ecr_push" {
  name = "go-api-github-ecr-push"
  assume_role_policy = jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Principal={Federated=local.github_provider},Action="sts:AssumeRoleWithWebIdentity",Condition={StringEquals={"token.actions.githubusercontent.com:aud"="sts.amazonaws.com","token.actions.githubusercontent.com:sub"=local.github_sub}}}]})
}
resource "aws_iam_role_policy" "ecr_push" {
  role = aws_iam_role.ecr_push.id
  policy = jsonencode({Version="2012-10-17",Statement=[
    {Effect="Allow",Action=["ecr:GetAuthorizationToken"],Resource="*"},
    {Effect="Allow",Action=["ecr:BatchCheckLayerAvailability","ecr:CompleteLayerUpload","ecr:InitiateLayerUpload","ecr:PutImage","ecr:UploadLayerPart"],Resource=aws_ecr_repository.api.arn}
  ]})
}
output "ecr_repository_url" { value = aws_ecr_repository.api.repository_url }
output "github_ecr_role_arn" { value = aws_iam_role.ecr_push.arn }
