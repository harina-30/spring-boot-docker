# GitHub Actions → AWS OIDC setup for pushing to Amazon ECR

This document shows a minimal, secure setup using GitHub Actions OIDC to allow workflows to assume an IAM role and push container images to Amazon ECR without long-lived AWS secrets.

## 1) Overview
- Create an IAM role that trusts GitHub's OIDC provider (token.actions.githubusercontent.com).
- Attach a minimal IAM policy that allows the role to push images to a specific ECR repository.
- Store the role ARN as the repository secret `AWS_ROLE_TO_ASSUME` (or set it at org level).
- In the workflow, `aws-actions/configure-aws-credentials` will assume the role.

## 2) Example trust policy (replace ACCOUNT_ID and REPO details)
Save as `trust-policy.json` and replace placeholders:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG_OR_USER/YOUR_REPO:*"
        },
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

Notes:
- Lock `StringLike` to `repo:owner/repo:ref` or `repo:owner/repo:*` for more narrow scope.

## 3) Minimal ECR IAM policy for pushing
Save as `ecr-push-policy.json` (replace REGION, ACCOUNT_ID, REPO_NAME):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect":"Allow","Action":["ecr:GetAuthorizationToken"],"Resource":"*"},
    { "Effect":"Allow","Action":["ecr:CreateRepository","ecr:DescribeRepositories"],"Resource":"arn:aws:ecr:REGION:ACCOUNT_ID:repository/REPO_NAME"},
    { "Effect":"Allow","Action":["ecr:BatchCheckLayerAvailability","ecr:PutImage","ecr:InitiateLayerUpload","ecr:UploadLayerPart","ecr:CompleteLayerUpload"],"Resource":"arn:aws:ecr:REGION:ACCOUNT_ID:repository/REPO_NAME"}
  ]
}
```

## 4) Create role and attach policy (AWS CLI)

Replace placeholders and run:

```bash
aws iam create-role --role-name GitHubActionsECRRole --assume-role-policy-document file://trust-policy.json
aws iam put-role-policy --role-name GitHubActionsECRRole --policy-name ECRPushPolicy --policy-document file://ecr-push-policy.json
```

### Helper script (PowerShell)
A convenience PowerShell script is included in this repo to create the OIDC provider, role, and inline ECR policy in an idempotent way:

```powershell
# Run from the repo root (requires AWS CLI configured with an admin or IAM user that can create roles/policies)
.github\scripts\create-aws-oidc-role.ps1 -AccountId <ACCOUNT_ID> -Region <REGION> -RepoName <ECR_REPO> -GitHubRepo <owner/repo>
```

This script will also print the role ARN for you to copy into a GitHub repository secret named `AWS_ROLE_TO_ASSUME`.

## 5) Add role ARN to GitHub repo secrets
- Add repository secret `AWS_ROLE_TO_ASSUME` with value `arn:aws:iam::ACCOUNT_ID:role/GitHubActionsECRRole`.
- Also set `AWS_REGION` and `ECR_REPO` as secrets (unless you prefer repository variables).

## 6) Workflow configuration
In your workflow, call `aws-actions/configure-aws-credentials` and set `role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}` and `aws-region` to the region (this repo includes a sample workflow that supports both OIDC and classic credentials).

## 7) Security tips
- Prefer OIDC over long-lived access keys.
- Scope the `token.actions.githubusercontent.com:sub` condition to your repository and, if needed, to specific branches/tags.
- Review `sts:AssumeRoleWithWebIdentity` trust relationships periodically.

---
Thanks! If you'd like, I can also generate the exact AWS CLI commands to replace placeholders for your account and repo name.