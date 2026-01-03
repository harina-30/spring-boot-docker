<#
.SYNOPSIS
  Create an IAM Role for GitHub Actions OIDC to push images to Amazon ECR.

.DESCRIPTION
  Idempotent PowerShell helper that:
    - Optionally creates the OIDC provider for token.actions.githubusercontent.com
    - Creates an IAM Role trusting the OIDC provider scoped to a GitHub repo
    - Attaches an inline policy that allows pushing to a given ECR repository

USAGE
  .\create-aws-oidc-role.ps1 -AccountId 123456789012 -Region us-east-1 -RepoName my-ecr-repo -GitHubRepo owner/repo

REQUIREMENTS
  - AWS CLI v2 installed and configured with credentials that can create roles/policies
  - PowerShell 7+ recommended
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
    [Parameter(Mandatory=$true)][string]$AccountId,
    [Parameter(Mandatory=$true)][string]$Region,
    [Parameter(Mandatory=$true)][string]$RepoName,
    # GitHub repo in format owner/repo. This will be used in the OIDC trust condition.
    [Parameter(Mandatory=$true)][string]$GitHubRepo,
    [string]$RoleName = 'GitHubActionsECRRole',
    [switch]$CreateOidcProvider
)

function ExitWithError {
    param([string]$msg)
    Write-Host "ERROR: $msg" -ForegroundColor Red
    exit 1
} 

# Check AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    ExitWithError -msg "AWS CLI not found. Install AWS CLI v2 and ensure it's on PATH."
} 

$oidcUrl = 'https://token.actions.githubusercontent.com'
$oidcProviderArn = "arn:aws:iam::$AccountId:oidc-provider/token.actions.githubusercontent.com"

# 1) Create OIDC provider if requested or if provider doesn't exist
$providerExists = $false
try {
    $providers = (& aws iam list-open-id-connect-providers --output json) | ConvertFrom-Json
    foreach ($p in $providers.OpenIDConnectProviderList) {
        if ($p.Arn -eq $oidcProviderArn) { $providerExists = $true; break }
    }
} catch {
    # ignore and continue
}

if ($CreateOidcProvider -or -not $providerExists) {
    Write-Host "Creating OIDC provider (if missing)..." -ForegroundColor Cyan
    # stable GitHub thumbprint
    $thumbprint = '6938fd4d98bab03faadb97b34396831e3780aea1'
    try {
        & aws iam create-open-id-connect-provider --url $oidcUrl --client-id-list sts.amazonaws.com --thumbprint-list $thumbprint | Out-Null
        Write-Host "OIDC provider created or already exists." -ForegroundColor Green
    } catch {
        Write-Host "Warning: could not create provider (it may already exist). Continuing..." -ForegroundColor Yellow
    }
} else {
    Write-Host "OIDC provider already present: $oidcProviderArn" -ForegroundColor Green
}

# 2) Build trust policy JSON scoped to the GitHub repo
$trustFile = "trust-policy.json"
$safeSub = 'token_actions_githubusercontent_com_sub'
$safeAud = 'token_actions_githubusercontent_com_aud'
$trustPolicy = @{
    Version = '2012-10-17'
    Statement = @(
        @{
            Effect = 'Allow'
            Principal = @{ Federated = $oidcProviderArn }
            Action = 'sts:AssumeRoleWithWebIdentity'
            Condition = @{
                ($safeSub) = ("repo:{0}:*" -f $GitHubRepo)
                ($safeAud) = 'sts.amazonaws.com'
            }
        }
    )
}

$trustJson = ($trustPolicy | ConvertTo-Json -Depth 6)
$trustJson = $trustJson -replace 'token_actions_githubusercontent_com_sub','token.actions.githubusercontent.com:sub'
$trustJson = $trustJson -replace 'token_actions_githubusercontent_com_aud','token.actions.githubusercontent.com:aud'
$trustJson | Out-File -FilePath $trustFile -Encoding UTF8
Write-Host "Wrote trust policy to $trustFile" -ForegroundColor Cyan

# 3) Create the IAM role (idempotent)
$roleArn = "arn:aws:iam::$AccountId:role/$RoleName"
try {
    & aws iam get-role --role-name $RoleName --output json | Out-Null
    Write-Host "Role already exists: $roleArn" -ForegroundColor Green
} catch {
    Write-Host "Creating role: $RoleName" -ForegroundColor Cyan
    & aws iam create-role --role-name $RoleName --assume-role-policy-document file://$trustFile --description "Role for GitHub Actions OIDC to push to ECR" | Out-Null
    Write-Host "Role created: $roleArn" -ForegroundColor Green
}

# 4) Create ECR push policy JSON and attach as inline policy
$repoArn = 'arn:aws:ecr:' + $Region + ':' + $AccountId + ':repository/' + $RepoName
$ecrPolicy = @{
    Version = '2012-10-17'
    Statement = @(
        @{ Effect = 'Allow'; Action = @('ecr:GetAuthorizationToken'); Resource = '*' },
        @{ Effect = 'Allow'; Action = @('ecr:CreateRepository','ecr:DescribeRepositories'); Resource = $repoArn },
        @{ Effect = 'Allow'; Action = @('ecr:BatchCheckLayerAvailability','ecr:PutImage','ecr:InitiateLayerUpload','ecr:UploadLayerPart','ecr:CompleteLayerUpload'); Resource = $repoArn }
    )
}

$policyFile = "ecr-push-policy.json"
($ecrPolicy | ConvertTo-Json -Depth 6) | Out-File -FilePath $policyFile -Encoding UTF8
Write-Host "Wrote ECR policy to $policyFile" -ForegroundColor Cyan

Write-Host "Attaching inline policy 'ECRPushPolicy' to role $RoleName" -ForegroundColor Cyan
& aws iam put-role-policy --role-name $RoleName --policy-name ECRPushPolicy --policy-document file://$policyFile

# 5) Final output and next steps
Write-Host "\nDone. Role ARN: $roleArn" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1) Add repository secret 'AWS_ROLE_TO_ASSUME' with value: $roleArn" -ForegroundColor Yellow
Write-Host "  2) Add repository secret 'AWS_REGION' (if not already set) and 'ECR_REPO' (value: $RepoName)" -ForegroundColor Yellow
Write-Host "  3) Optionally scope the OIDC trust condition more tightly (e.g. specific branch) in $trustFile" -ForegroundColor Yellow
Write-Host "  4) Run the GitHub Actions workflow; it will use the role via OIDC and push images to ECR" -ForegroundColor Yellow

# Clean up temporary files comment: we leave policy files in-place for review

# Exit
exit 0
