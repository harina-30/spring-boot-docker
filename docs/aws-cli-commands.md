# AWS CLI & PowerShell commands (filled with your values)

Use these commands to set up OIDC, create the role, attach the ECR policy, and verify everything.

Values used in these commands:
- AWS Account ID: **665168932067**
- AWS Region: **eu-north-1**
- ECR repo name: **coursera/spring-boot-docker**
- GitHub repo (OIDC trust scope): **harina-30/spring-boot-docker**

---

## 1) (Optional) Create OIDC provider

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

If the provider already exists, you'll see an error and can ignore it.

---

## 2) Create `trust-policy.json` (scoped to your repo)

Save this JSON as `trust-policy.json` and update if you want stricter scoping.

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect":"Allow",
    "Principal":{"Federated":"arn:aws:iam::665168932067:oidc-provider/token.actions.githubusercontent.com"},
    "Action":"sts:AssumeRoleWithWebIdentity",
    "Condition":{
      "StringLike":{"token.actions.githubusercontent.com:sub":"repo:harina-30/spring-boot-docker:*"},
      "StringEquals":{"token.actions.githubusercontent.com:aud":"sts.amazonaws.com"}
    }
  }]
}
```

Then create the role:

```bash
aws iam create-role --role-name GitHubActionsECRRole \
  --assume-role-policy-document file://trust-policy.json \
  --description "Role for GitHub Actions OIDC to push to ECR"
```

---

## 3) Create `ecr-push-policy.json` (inline policy)

Save this as `ecr-push-policy.json` (replace if you want different scoping):

```json
{
  "Version":"2012-10-17",
  "Statement":[
    {"Effect":"Allow","Action":["ecr:GetAuthorizationToken"],"Resource":"*"},
    {"Effect":"Allow","Action":["ecr:CreateRepository","ecr:DescribeRepositories"],"Resource":"arn:aws:ecr:eu-north-1:665168932067:repository/coursera/spring-boot-docker"},
    {"Effect":"Allow","Action":["ecr:BatchCheckLayerAvailability","ecr:PutImage","ecr:InitiateLayerUpload","ecr:UploadLayerPart","ecr:CompleteLayerUpload"],"Resource":"arn:aws:ecr:eu-north-1:665168932067:repository/coursera/spring-boot-docker"}
  ]
}
```

Attach policy as inline policy to the role:

```bash
aws iam put-role-policy --role-name GitHubActionsECRRole --policy-name ECRPushPolicy --policy-document file://ecr-push-policy.json
```

---

## 4) Add GitHub secrets

In your GitHub repo (Settings → Secrets and variables → Actions) add:
- `AWS_ROLE_TO_ASSUME` = `arn:aws:iam::665168932067:role/GitHubActionsECRRole`
- `AWS_REGION` = `eu-north-1`
- `ECR_REPO` = `coursera/spring-boot-docker`

---

## 5) Test the OIDC role from GitHub Actions

Use the `Test OIDC Role` workflow added in `.github/workflows/test-oidc.yml`. Or trigger it manually in Actions → Workflows → Test OIDC Role → Run workflow.

It will run `aws sts get-caller-identity` and print the identity assumed.

---

## 6) PowerShell helper (alternative)

You can also run the repo helper which performs these steps idempotently. From repo root in PowerShell (requires AWS CLI configured):

```powershell
.\.github\scripts\create-aws-oidc-role.ps1 -AccountId 665168932067 -Region eu-north-1 -RepoName "coursera/spring-boot-docker" -GitHubRepo "harina-30/spring-boot-docker" -CreateOidcProvider
```

This script will write `trust-policy.json` and `ecr-push-policy.json` for review and print the role ARN.

---

If you want, I can run a quick validation in GitHub (open a PR and trigger the test workflow) — say `open PR` and I'll create a branch and open a PR with these changes.