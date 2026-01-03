# build-and-push.ps1

Quick helper to build and push a multi-arch Docker image to Amazon ECR.

## Usage

1. Set required environment variables in your PowerShell session:

```powershell
$env:AWS_ACCOUNT_ID = "123456789012"
$env:AWS_REGION = "us-east-1"
$env:ECR_REPO = "my-repo"
```

2. Ensure AWS credentials are available (either `aws configure` or env vars):

```powershell
aws configure
# or
$env:AWS_ACCESS_KEY_ID = "..."; $env:AWS_SECRET_ACCESS_KEY = "..."
```

3. Run the script:

```powershell
.\.github\scripts\build-and-push.ps1
```

## Notes
- The script requires Docker and AWS CLI v2 on PATH. Docker Desktop includes Buildx support.
- The script will create an ECR repository when missing, log Docker into ECR, and push `:latest` and `:sha-<short-sha>` tags.
- Do not store secrets in the repo. Use GitHub repository secrets or environment variables locally.
