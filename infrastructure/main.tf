#### DB Password creation
resource "random_string" "pass_db" {
  length = 10
}

## Getting aws account ID 
data "aws_caller_identity" "ID_CURRENT_ACCOUNT" {}

data "aws_availability_zones" "available" {
  state = "available"
}

## variables to put in secret manager
locals {
  db_credentials = {
    database__client               = "mysql"
    database__connection__host     = element(split(":", module.db_ghost.db_instance_endpoint), 0)
    database__connection__user     = "admin"
    database__connection__password = random_string.pass_db.result
    database__connection__database = "ghostdb"
    url                            = "http://${module.alb.DNS_ALB}"
    storage__active                = "s3"
    storage__s3__region            = var.region
    storage__s3__bucket            = "ghost-content-${var.env}"
    ghost_api_key                  = "empty"
  }
}

############################################
###### Networking resources creation

module "vpc_creation" {
  source           = "./modules/networking"
  NAME             = "VPC"
  ENV              = var.env
  CIDR             = "10.100.0.0/16"
  AZS              = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1], data.aws_availability_zones.available.names[2]]
  PRIVATE_SUBNETS  = ["10.100.0.0/22", "10.100.64.0/22", "10.100.128.0/22"]
  DATABASE_SUBNETS = ["10.100.4.0/22", "10.100.68.0/22", "10.100.132.0/22"]
  PUBLIC_SUBNETS   = ["10.100.32.0/22", "10.100.96.0/22", "10.100.160.0/22"]
}

######################
### IAM resources

# Role for ecs tasks
module "ecs_role" {
  source          = "./modules/iam"
  NAME            = "ecs-role-ghost"
  CREATE_ECS_ROLE = true
}

## Policy for ecs role
module "policy_for_ecs" {
  source        = "./modules/iam"
  NAME          = "ecs-role-${var.env}"
  CREATE_POLICY = true
  ATTACH_TO     = module.ecs_role.NAME_ROLE
  POLICY        = data.aws_iam_policy_document.ecs_role_policy.json
}

##########################
## Secret manager

# KMS ky to encrypt at rest secret manager
module "kms_secret_manager" {
  source = "./modules/kms"
  NAME   = "KMS-SecretManager-${var.env}"
  POLICY = data.aws_iam_policy_document.kms_policy.json
}

### Secret Manager Creation

module "secret_manager" {
  source    = "./modules/secret-manager"
  NAME      = "secretsm_${var.env}"
  RETENTION = 10
  KMS_KEY   = module.kms_secret_manager.ARN_KMS
  POLICY    = data.aws_iam_policy_document.secret_manager_policy.json
}

### Setting values in secret manager
resource "aws_secretsmanager_secret_version" "secretsvalues" {
  secret_id     = module.secret_manager.SECRET_ID
  secret_string = jsonencode(local.db_credentials)
}


##########################
## ALB Resources

## Target Groups Creation

module "target_group" {
  source              = "./modules/alb"
  NAME                = "tg-ghost-${var.env}"
  CREATE_TARGET_GROUP = true
  PORT                = 80
  PROTOCOL            = "HTTP"
  VPC                 = module.vpc_creation.main.vpc_id
  TG_TYPE             = "ip"
  HEALTH_CHECK_PATH   = "/"
  HEALTH_CHECK_PORT   = "2368"
}

### Security Group for ALB

resource "aws_security_group" "sg_alb_ghost" {
  name        = "sg_alb_${var.env}"
  description = "controls access to the ALB"
  vpc_id      = module.vpc_creation.main.vpc_id
  tags = {
    Name = "sg_alb${var.env}"
  }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#### ALB creation

module "alb" {
  source         = "./modules/alb"
  NAME           = "alb-ghost"
  CREATE_ALB     = true
  ENABLE_HTTPS   = false
  TARGET_GROUP   = module.target_group.ARN_TG
  SUBNETS        = module.vpc_creation.main.public_subnets
  SECURITY_GROUP = aws_security_group.sg_alb_ghost.id
}

##########################
#### ECS Resources 

# Creating ECR Repo to store Docker Images

resource "aws_ecr_repository" "ecr_ghost" {
  name                 = "ghost-nordcloud-${var.env}"
  image_tag_mutability = "MUTABLE"
}

### Security group for ECS Tasks
resource "aws_security_group" "sg_ecs_tasks" {
  name        = "sg_ecs_${var.env}"
  description = "controls access to the ecs tasks"
  vpc_id      = module.vpc_creation.main.vpc_id
  tags = {
    Name = "sg_ecs_${var.env}"
  }
  ingress {
    protocol        = "tcp"
    from_port       = 2368
    to_port         = 2368
    security_groups = [aws_security_group.sg_alb_ghost.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

### ECS Cluster Creation
resource "aws_ecs_cluster" "cluster" {
  name = "Cluster_${var.env}"
}


### ECS task definition
module "task_definition" {
  depends_on     = [module.secret_manager, aws_ecr_repository.ecr_ghost]
  source         = "./modules/ecs/taskdefinition"
  NAME           = var.env
  TASK_ROLE      = module.ecs_role.ARN_ROLE
  ARN_ROLE       = module.ecs_role.ARN_ROLE
  CPU            = 512
  MEMORY         = "1024"
  DOCKER_REPO    = aws_ecr_repository.ecr_ghost.repository_url
  REGION         = var.region
  SECRET_ARN     = module.secret_manager.SECRET_ARN
  CONTAINER_PORT = 2368
}

### Creating ECS Service
module "ecs_service" {
  depends_on          = [module.alb]
  source              = "./modules/ecs/service"
  NAME                = var.env
  DESIRED_TASKS       = 1
  REGION              = var.region
  ARN_SECURITY_GROUP  = aws_security_group.sg_ecs_tasks.id
  ECS_CLUSTER_ID      = aws_ecs_cluster.cluster.id
  ARN_TARGET_GROUP    = module.target_group.ARN_TG
  ARN_TASK_DEFINITION = module.task_definition.ARN_TASK_DEFINITION
  SUBNET_ID           = module.vpc_creation.main.private_subnets
  CONTAINER_PORT      = 2368
  CLUSTER_NAME        = aws_ecs_cluster.cluster.name
  MAX_NUMBER_TASKS    = 10
  MIN_NUMBER_TASKS    = 1
  CPU_THRESHOLD       = 50
  MEMORY_THRESHOLD    = 50
  ENABLE_AUTOSCALING  = true
}


##########################
### RDS Creation

### Scurity Group for RDS
resource "aws_security_group" "sg_ecs_rds" {
  name        = "sg_rds_${var.env}"
  description = "controls access to the rds instance"
  vpc_id      = module.vpc_creation.main.vpc_id
  tags = {
    Name = "sg_ecs_${var.env}"
  }
  ingress {
    protocol        = "tcp"
    from_port       = 3306
    to_port         = 3306
    security_groups = [aws_security_group.sg_ecs_tasks.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS instance creation

module "db_ghost" {
  source                 = "terraform-aws-modules/rds/aws"
  version                = "3.4.1"
  identifier             = "ghost-db-${var.env}"
  engine                 = "mysql"
  engine_version         = "8.0.20"
  family                 = "mysql8.0" # DB parameter group
  major_engine_version   = "8.0"      # DB option group
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_encrypted      = true
  name                   = "ghostdb"
  username               = "admin"
  password               = random_string.pass_db.result
  port                   = 3306
  multi_az               = false
  publicly_accessible    = false
  subnet_ids             = module.vpc_creation.main.database_subnets
  vpc_security_group_ids = [aws_security_group.sg_ecs_rds.id]
  skip_final_snapshot    = true
}

###################
### S3 bucket

module "s3-content" {
  source              = "terraform-aws-modules/s3-bucket/aws"
  version             = "2.11.1"
  bucket              = "ghost-content-${var.env}"
  block_public_policy = true
  block_public_acls   = true
  force_destroy       = true
  restrict_public_buckets = true
}

######################
### Lambda Function

### Creating lambga layers for JWT and Request package that we will need
# JWT
resource "aws_lambda_layer_version" "jwt" {
  filename   = "../lambda/jwt_layer.zip"
  layer_name = "jwt"
  compatible_architectures = ["x86_64"]
}

# Requests Packagess
resource "aws_lambda_layer_version" "requests" {
  filename   = "../lambda/requests_layer.zip"
  layer_name = "requests"
  compatible_architectures = ["x86_64"]
}


### Lambda role

resource "aws_iam_role" "role_lambda" {
  name = "role_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


### IAM policy for lambda
module "policy_for_lambda" {
  source        = "./modules/iam"
  NAME          = "lambda-role-${var.env}"
  CREATE_POLICY = true
  ATTACH_TO     = aws_iam_role.role_lambda.name
  POLICY        = data.aws_iam_policy_document.lambda_policy.json
}

### Lambda function
resource "aws_lambda_function" "test_lambda" {
  filename      = "../lambda/python_code.zip"
  function_name = "delete_ghost_post"
  role          = aws_iam_role.role_lambda.arn
  source_code_hash = filebase64sha256("../lambda/python_code.zip")
  runtime = "python3.9"
  handler = "lambda_function.lambda_handler"
  environment {
    variables = {
      REGION = var.region
      ARN_SECRET_MANAGER = module.secret_manager.SECRET_ARN
    }
  }
  layers = [aws_lambda_layer_version.jwt.arn,aws_lambda_layer_version.requests.arn]
}

##############################
## CloudWatch alarms

##########################
### SNS Topic

resource "aws_sns_topic" "infra_alarms" {
  name = "infra_alerts"
}


resource "aws_sns_topic_subscription" "email_suscription" {
  topic_arn = aws_sns_topic.infra_alarms.arn
  protocol  = "email"
  endpoint  = "danielrivera846@gmail.com"
}


#### ECS Metrics
resource "aws_cloudwatch_metric_alarm" "CPU_ECS" {
  alarm_name                = "High-CPU-ECS"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/ECS "
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "60"
  alarm_description         = "monitoring cpu in ecs containers"
  insufficient_data_actions = []
  alarm_actions             = [ resource.aws_sns_topic.infra_alarms.arn ]
  dimensions = {
        ServiceName = module.ecs_service.ecs_service_name
  }
  
}

resource "aws_cloudwatch_metric_alarm" "Memory_ECS" {
  alarm_name                = "High-Memory-ECS"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "MemoryUtilization"
  namespace                 = "AWS/ECS "
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "60"
  alarm_description         = "monitoring memory in ecs containers"
  alarm_actions             = [ resource.aws_sns_topic.infra_alarms.arn ]
  insufficient_data_actions = []
  dimensions = {
        ServiceName = module.ecs_service.ecs_service_name
  }
}


# ALB Metrics

resource "aws_cloudwatch_metric_alarm" "active_connection" {
  alarm_name                = "active-connection-alb"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "ActiveConnectionCount"
  namespace                 = "AWS/ApplicationELB "
  period                    = "60"
  statistic                 = "SampleCount"
  threshold                 = "100"
  alarm_description         = "monitoring number of connection in alb"
  alarm_actions             = [ resource.aws_sns_topic.infra_alarms.arn ]
  insufficient_data_actions = []
  dimensions = {
        LoadBalancer = module.alb.ARN_ALB_SUFFIX
  }
}

resource "aws_cloudwatch_metric_alarm" "HTTP_ELB_500" {
  alarm_name                = "HTTP ELB CODE"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "HTTPCode_ELB_500_Count"
  namespace                 = "AWS/ApplicationELB "
  period                    = "60"
  statistic                 = "SampleCount"
  threshold                 = "100"
  alarm_description         = "monitoring http codes from ALB"
  insufficient_data_actions = []
  alarm_actions             = [ resource.aws_sns_topic.infra_alarms.arn ]
  dimensions = {
        LoadBalancer = module.alb.ARN_ALB_SUFFIX
  }
}


resource "aws_cloudwatch_metric_alarm" "Healthy-hosts" {
  alarm_name                = "healthy-host-alb"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "UnhealthyHostCount"
  namespace                 = "AWS/ApplicationELB "
  period                    = "60"
  statistic                 = "SampleCount"
  threshold                 = "100"
  alarm_description         = "monitoring number of ecs task healthy"
  insufficient_data_actions = []
  alarm_actions             = [ resource.aws_sns_topic.infra_alarms.arn ]
  dimensions = {
        LoadBalancer = module.alb.ARN_ALB_SUFFIX
        TargetGroup  = module.target_group.ARN_SUFFIX_TG
  }
}

resource "aws_cloudwatch_metric_alarm" "Target-http5xx" {
  alarm_name                = "app-http-500"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "HTTPCode_Target_5XX_Count"
  namespace                 = "AWS/ApplicationELB "
  period                    = "60"
  statistic                 = "SampleCount"
  threshold                 = "50"
  alarm_description         = "monitoring number of http 5xx that the application sends"
  insufficient_data_actions = []
  alarm_actions             = [ resource.aws_sns_topic.infra_alarms.arn ]
  dimensions = {
        LoadBalancer = module.alb.ARN_ALB_SUFFIX
        TargetGroup  = module.target_group.ARN_SUFFIX_TG
  }
}

