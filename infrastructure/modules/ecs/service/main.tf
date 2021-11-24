resource "aws_ecs_service" "ECS_SERVICE" {
  name                              = "Service-${var.NAME}"
  cluster                           = var.ECS_CLUSTER_ID
  task_definition                   = var.ARN_TASK_DEFINITION
  desired_count                     = var.DESIRED_TASKS
  health_check_grace_period_seconds = 10
  launch_type                       = "FARGATE"
  network_configuration {
    security_groups = [var.ARN_SECURITY_GROUP]
    subnets         = [var.SUBNET_ID[0], var.SUBNET_ID[1]]
  }
  load_balancer {
    target_group_arn = var.ARN_TARGET_GROUP
    container_name   = "Container-${var.NAME}"
    container_port   = var.CONTAINER_PORT
  }
}


#***  Auto Scaling ECS *****

#--- auto scaling ecs ---
resource "aws_appautoscaling_target" "AUTOSCALING_ECS" {
  count              = var.ENABLE_AUTOSCALING == true ? 1 : 0
  max_capacity       = var.MAX_NUMBER_TASKS
  min_capacity       = var.MIN_NUMBER_TASKS
  resource_id        = "service/${var.CLUSTER_NAME}/${aws_ecs_service.ECS_SERVICE.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

#--- auto scaling policies ---

#--- auto scaling cpu up ---
resource "aws_appautoscaling_policy" "ECS_HIGH_CPU" {
  count              = var.ENABLE_AUTOSCALING == true ? 1 : 0
  name               = "asg-scale-up-cpu-${var.NAME}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.AUTOSCALING_ECS[0].resource_id
  scalable_dimension = aws_appautoscaling_target.AUTOSCALING_ECS[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.AUTOSCALING_ECS[0].service_namespace
  target_tracking_scaling_policy_configuration {
    target_value       = var.CPU_THRESHOLD
    scale_in_cooldown  = 600
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

#--- auto scaling memory up ---

resource "aws_appautoscaling_policy" "ECS_HIGH_MEMORY" {
  count              = var.ENABLE_AUTOSCALING == true ? 1 : 0
  name               = "asg-scale-up-memory-${var.NAME}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.AUTOSCALING_ECS[0].resource_id
  scalable_dimension = aws_appautoscaling_target.AUTOSCALING_ECS[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.AUTOSCALING_ECS[0].service_namespace
  target_tracking_scaling_policy_configuration {
    target_value       = var.MEMORY_THRESHOLD
    scale_in_cooldown  = 600
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}


### CloudWatch Alarms

# --- High memory alarm  --- 
resource "aws_cloudwatch_metric_alarm" "ALARM_HIGH_MEMORY" {
  count               = var.ENABLE_AUTOSCALING == true ? 1 : 0
  alarm_name          = "high-memory-ecs-service-${var.NAME}"
  alarm_description   = "High Memory Landing Page for  ecs service for ${var.NAME}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = var.MEMORY_THRESHOLD
  dimensions = {
    "ServiceName" = aws_ecs_service.ECS_SERVICE.name,
    "ClusterName" = var.CLUSTER_NAME
  }
}


# --- High CPU alarm  --- 
resource "aws_cloudwatch_metric_alarm" "ALARM_HIGH_CPU" {
  count               = var.ENABLE_AUTOSCALING == true ? 1 : 0
  alarm_name          = "high-cpu-ecs-service-${var.NAME}"
  alarm_description   = "High CPUPolicy Landing Page for  ecs service for ${var.NAME}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = var.CPU_THRESHOLD
  dimensions = {
    "ServiceName" = aws_ecs_service.ECS_SERVICE.name,
    "ClusterName" = var.CLUSTER_NAME
  }
}
