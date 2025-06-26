# ECS CodeDeploy Permission Fix

## Problem
The error "The provided role does not have sufficient permissions to access ECS" occurs when the CodeDeploy service role lacks the necessary permissions to interact with ECS services.

## Solution Steps

### 1. Create/Update IAM Role for CodeDeploy

#### Option A: Using AWS CLI
```bash
# Create the CodeDeploy service role
aws iam create-role \
  --role-name CodeDeployServiceRoleForECS \
  --assume-role-policy-document file://iam-policies/codedeploy-trust-policy.json

# Attach the custom policy
aws iam put-role-policy \
  --role-name CodeDeployServiceRoleForECS \
  --policy-name CodeDeployECSPolicy \
  --policy-document file://iam-policies/codedeploy-ecs-role-policy.json

# Attach AWS managed policy for CodeDeploy ECS
aws iam attach-role-policy \
  --role-name CodeDeployServiceRoleForECS \
  --policy-arn arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS
```

#### Option B: Using AWS Console
1. Go to IAM Console > Roles > Create Role
2. Select "CodeDeploy" as the service
3. Select "CodeDeploy - ECS" as the use case
4. Attach the policies:
   - `AWSCodeDeployRoleForECS` (AWS managed)
   - Custom policy from `codedeploy-ecs-role-policy.json`

### 2. Update CodeDeploy Application

```bash
# Update your CodeDeploy application configuration
aws deploy update-application \
  --application-name <your-app-name> \
  --service-role-arn arn:aws:iam::<account-id>:role/CodeDeployServiceRoleForECS
```

### 3. Verify ECS Task Execution Role

Ensure your ECS task execution role has these permissions:
```bash
# Check if the role exists
aws iam get-role --role-name ecsTaskExecutionRole

# If not, create it
aws iam create-role \
  --role-name ecsTaskExecutionRole \
  --assume-role-policy-document '{
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
  }'

# Attach the managed policy
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

### 4. Update Pipeline Configuration

In your CodePipeline, ensure the Deploy stage uses the correct service role:

```json
{
  "Name": "Deploy",
  "ActionTypeId": {
    "Category": "Deploy",
    "Owner": "AWS",
    "Provider": "CodeDeployToECS",
    "Version": "1"
  },
  "Configuration": {
    "ApplicationName": "your-ecs-app",
    "DeploymentGroupName": "your-deployment-group",
    "ServiceRoleArn": "arn:aws:iam::<account-id>:role/CodeDeployServiceRoleForECS"
  }
}
```

## Troubleshooting

### Check Current Role Permissions
```bash
# List attached policies
aws iam list-attached-role-policies --role-name CodeDeployServiceRoleForECS

# Get inline policies
aws iam list-role-policies --role-name CodeDeployServiceRoleForECS
```

### Test Role Permissions
```bash
# Assume the role and test ECS access
aws sts assume-role \
  --role-arn arn:aws:iam::<account-id>:role/CodeDeployServiceRoleForECS \
  --role-session-name test-session

# Test ECS describe services (using temporary credentials)
aws ecs describe-services --cluster <cluster-name> --services <service-name>
```

### Common Issues
1. **Missing AWSCodeDeployRoleForECS policy** - Attach the AWS managed policy
2. **Incorrect trust relationship** - Ensure CodeDeploy service can assume the role
3. **Missing ECS permissions** - Add the custom ECS permissions from the policy file
4. **Wrong service role in pipeline** - Update the pipeline configuration

## Files Created
- `iam-policies/codedeploy-trust-policy.json` - Trust policy for CodeDeploy service
- `iam-policies/codedeploy-ecs-role-policy.json` - ECS permissions for CodeDeploy role
