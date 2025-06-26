# ECS CodeDeploy Permission Fix Script (PowerShell)
# This script creates the necessary IAM role and policies for CodeDeploy to work with ECS

$ErrorActionPreference = "Stop"

# Variables
$ROLE_NAME = "CodeDeployServiceRoleForECS"
$POLICY_NAME = "CodeDeployECSPolicy"
$ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)

Write-Host "Setting up CodeDeploy permissions for ECS..."
Write-Host "Account ID: $ACCOUNT_ID"

# Check if role exists
try {
    aws iam get-role --role-name $ROLE_NAME 2>$null | Out-Null
    Write-Host "Role $ROLE_NAME already exists. Updating policies..."
} catch {
    Write-Host "Creating role $ROLE_NAME..."
    aws iam create-role `
        --role-name $ROLE_NAME `
        --assume-role-policy-document file://iam-policies/codedeploy-trust-policy.json
    
    Write-Host "Role created successfully."
}

# Attach AWS managed policy
Write-Host "Attaching AWS managed policy AWSCodeDeployRoleForECS..."
aws iam attach-role-policy `
    --role-name $ROLE_NAME `
    --policy-arn arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS

# Add custom ECS permissions
Write-Host "Adding custom ECS permissions..."
aws iam put-role-policy `
    --role-name $ROLE_NAME `
    --policy-name $POLICY_NAME `
    --policy-document file://iam-policies/codedeploy-ecs-role-policy.json

# Verify ECS Task Execution Role exists
Write-Host "Checking ECS Task Execution Role..."
try {
    aws iam get-role --role-name ecsTaskExecutionRole 2>$null | Out-Null
    Write-Host "ECS Task Execution Role already exists."
} catch {
    Write-Host "Creating ECS Task Execution Role..."
    $trustPolicy = @'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ecs-tasks.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
'@
    
    aws iam create-role `
        --role-name ecsTaskExecutionRole `
        --assume-role-policy-document $trustPolicy
    
    aws iam attach-role-policy `
        --role-name ecsTaskExecutionRole `
        --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
}

Write-Host ""
Write-Host "Setup complete! Role ARN: arn:aws:iam::$ACCOUNT_ID`:role/$ROLE_NAME"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Update your CodeDeploy application to use this service role"
Write-Host "2. Ensure your CodePipeline Deploy stage references this role"
Write-Host "3. Test the deployment pipeline"
Write-Host ""
Write-Host "Role ARN to use in your pipeline:"
Write-Host "arn:aws:iam::$ACCOUNT_ID`:role/$ROLE_NAME"
