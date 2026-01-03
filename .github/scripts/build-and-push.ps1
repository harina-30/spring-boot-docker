<#
  .SYNOPSIS
    Helper script to build multi-arch Docker image and push to Amazon ECR.

  USAGE
    - Set environment variables: AWS_ACCOUNT_ID, AWS_REGION, ECR_REPO
    - Ensure AWS credentials are configured (aws configure) or exported as env vars
    - Run in PowerShell: `.\.github\scripts\build-and-push.ps1`

  NOTES
    - This script uses Docker Buildx to build and push multi-arch images as in the GitHub Actions workflow.
    - It does NOT store or print any secrets.
#>

$ErrorActionPreference = 'Stop'

function ExitWithError {
    param([string]$msg)
    Write-Host "ERROR: $msg" -ForegroundColor Red
    exit 1
} 

Write-Host "Starting local build & push to ECR..." -ForegroundColor Cyan

# Required environment variables
$required = @('AWS_ACCOUNT_ID','AWS_REGION','ECR_REPO')
$missing = @()
foreach ($name in $required) {
    $item = Get-Item -Path ("Env:" + $name) -ErrorAction SilentlyContinue
    if (-not $item -or [string]::IsNullOrEmpty($item.Value)) { $missing += $name }
}
if ($missing.Count -gt 0) {
    $missingList = $missing -join ', '
    $example = '$env:AWS_ACCOUNT_ID=''123456789012'''
    $msg = "Missing required env vars: $missingList. Set them and retry. Example: $example"
    ExitWithError -msg $msg
}  

# Check for required CLI tools
if (-not (Get-Command -Name aws -ErrorAction SilentlyContinue)) {
    ExitWithError -msg "AWS CLI not found. Install AWS CLI v2 and ensure it's on PATH."
} 

if (-not (Get-Command -Name docker -ErrorAction SilentlyContinue)) {
    ExitWithError -msg "Docker not found. Install Docker Desktop and ensure Docker is running."
}  

# Ensure buildx builder
$builder = 'mybuilder'
$exists = $false
try {
    docker buildx inspect $builder | Out-Null
    $exists = $true
} catch {
    $exists = $false
}

if (-not $exists) {
    Write-Host "Creating and using buildx builder '$builder'..." -ForegroundColor Yellow
    docker buildx create --name $builder --use | Out-Null
    docker buildx inspect --bootstrap | Out-Null
} else {
    Write-Host "Using existing buildx builder '$builder'" -ForegroundColor Green
    docker buildx use $builder | Out-Null
} 

$account = $env:AWS_ACCOUNT_ID
$region = $env:AWS_REGION
$repo = $env:ECR_REPO
$registry = '{0}.dkr.ecr.{1}.amazonaws.com' -f $account, $region
$fullImage = '{0}/{1}:latest' -f $registry, $repo

Write-Host "Ensuring ECR repository exists: $repo in region $($env:AWS_REGION)" -ForegroundColor Cyan
try {
    aws ecr describe-repositories --repository-names $repo --region $env:AWS_REGION | Out-Null
} catch {
    Write-Host "Repository not found. Creating: $repo" -ForegroundColor Yellow
    aws ecr create-repository --repository-name $repo --region $env:AWS_REGION | Out-Null
}

Write-Host "Logging Docker into ECR ($registry)" -ForegroundColor Cyan
aws ecr get-login-password --region $env:AWS_REGION | docker login --username AWS --password-stdin $registry

# Determine SHA tag
try {
    $sha = (& git rev-parse --short HEAD).Trim()
} catch {
    $sha = "local"
}
$shaTag = "$registry/$repo:sha-$sha"

Write-Host "Building and pushing multi-arch image to ECR:" -ForegroundColor Cyan
Write-Host "  latest -> $fullImage" -ForegroundColor DarkCyan
Write-Host "  sha    -> $shaTag" -ForegroundColor DarkCyan

# Build and push (multi-arch)
& docker buildx build --platform linux/amd64,linux/arm64 -t $fullImage -t $shaTag --push .

Write-Host "Build and push complete." -ForegroundColor Green
Write-Host "You should now see images in: $registry/$repo" -ForegroundColor Green

# End

# Linter refresh: no-op comment to force analyzer refresh
