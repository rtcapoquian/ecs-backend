#!/bin/bash

# ECS CodeDeploy Permission Fix Script
# This script creates the necessary IAM role and policies for CodeDeploy to work with ECS

set -e

# Variables
ROLE_NAME="CodeDeployServiceRoleForECS"
POLICY_NAME="CodeDeployECSPolicy"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Setting up CodeDeploy permissions for ECS..."
echo "Account ID: $ACCOUNT_ID"

# Check if role exists
if aws iam get-role --role-name $ROLE_NAME >/dev/null 2>&1; then
    echo "Role $ROLE_NAME already exists. Updating policies..."
else
    echo "Creating role $ROLE_NAME..."
    aws iam create-role \
        --role-name $ROLE_NAME \
        --assume-role-policy-document file://iam-policies/codedeploy-trust-policy.json
    
    echo "Role created successfully."
fi

# Attach AWS managed policy
echo "Attaching AWS managed policy AWSCodeDeployRoleForECS..."
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS

# Add custom ECS permissions
echo "Adding custom ECS permissions..."
aws iam put-role-policy \
    --role-name $ROLE_NAME \
    --policy-name $POLICY_NAME \
    --policy-document file://iam-policies/codedeploy-ecs-role-policy.json

# Verify ECS Task Execution Role exists
echo "Checking ECS Task Execution Role..."
if aws iam get-role --role-name ecsTaskExecutionRole >/dev/null 2>&1; then
    echo "ECS Task Execution Role already exists."
else
    echo "Creating ECS Task Execution Role..."
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
    
    aws iam attach-role-policy \
        --role-name ecsTaskExecutionRole \
        --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
fi

echo ""
echo "Setup complete! Role ARN: arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME"
echo ""
echo "Next steps:"
echo "1. Update your CodeDeploy application to use this service role"
echo "2. Ensure your CodePipeline Deploy stage references this role"
echo "3. Test the deployment pipeline"
echo ""
echo "Role ARN to use in your pipeline:"
echo "arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME"
