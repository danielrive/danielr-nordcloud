#!/bin/bash

# $1 = aws region
# $2 = environment name
# $3 = profile

set -e 
echo "....... packing lambda code"
cd lambda
zip -r python_code.zip lambda_function.py
cd ..

echo "....... Deploying infrastructure"

cd infrastructure 

echo ".......... Running terraform init"
terraform init

echo "............ Running terraform apply"

terraform apply -var region=$1 -var env=$2 -var profile_name=$3 -auto-approve

echo "............. Gettig account number to create ECR URI"

account_id="$(aws sts get-caller-identity --query Account --output text --profile $3)"

ecr="$account_id.dkr.ecr.$1.amazonaws.com/ghost-nordcloud-$2"

echo "................ Building docker image"

cd ..
docker build -t "$ecr:latest" --no-cache .  

echo "................... Pushing image to $3"

aws ecr get-login-password --region $1 --profile $3 | docker login --username AWS --password-stdin "$account_id.dkr.ecr.$1.amazonaws.com"

docker push "$ecr:latest"
