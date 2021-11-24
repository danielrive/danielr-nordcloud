#!/bin/bash

echo "building docker image"

docker build -t $3 --no-cache .  

echo "pushing image to $3"

aws ecr get-login-password --region $1 --profile $2 | docker login --username AWS --password-stdin $3

docker push $3
