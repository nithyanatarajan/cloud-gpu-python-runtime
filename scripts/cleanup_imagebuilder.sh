#!/bin/bash
set -ex

REGION="ap-south-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Resource Names
COMPONENT_NAME="gpu-prep-component"
RECIPE_NAME="gpu-prep-recipe"
PIPELINE_NAME="gpu-prep-pipeline"

# Construct ARNs
COMPONENT_ARN="arn:aws:imagebuilder:${REGION}:${ACCOUNT_ID}:component/${COMPONENT_NAME}/1.0.0/1"
RECIPE_ARN="arn:aws:imagebuilder:${REGION}:${ACCOUNT_ID}:image-recipe/${RECIPE_NAME}/1.0.0"
PIPELINE_ARN="arn:aws:imagebuilder:${REGION}:${ACCOUNT_ID}:image-pipeline/${PIPELINE_NAME}"

echo "Deleting Image Pipeline: $PIPELINE_NAME"
aws imagebuilder delete-image-pipeline --image-pipeline-arn "$PIPELINE_ARN" --region "$REGION" || true

echo "Deleting Image Recipe: $RECIPE_NAME"
aws imagebuilder delete-image-recipe --image-recipe-arn "$RECIPE_ARN" --region "$REGION" || true

echo "Deleting Component: $COMPONENT_NAME"
aws imagebuilder delete-component --component-build-version-arn "$COMPONENT_ARN" --region "$REGION" || true

echo "Cleanup complete."
