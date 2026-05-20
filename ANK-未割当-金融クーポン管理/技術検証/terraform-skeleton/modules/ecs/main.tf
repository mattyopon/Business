terraform {
  required_version = "~> 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }
}

resource "aws_ecs_cluster" "this" {
  name = "${var.prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      kms_key_id = var.kms_key_arn
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.exec.name
      }
    }
  }

  tags = var.tags
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

resource "aws_cloudwatch_log_group" "exec" {
  name              = "/aws/ecs/${var.prefix}/exec"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# ----------------------------------------
# Service (例: 利用判定 API)
# ----------------------------------------

resource "aws_cloudwatch_log_group" "service" {
  for_each = var.services

  name              = "/aws/ecs/${var.prefix}/${each.key}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_ecs_task_definition" "service" {
  for_each = var.services

  family                   = "${var.prefix}-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = each.value.execution_role_arn
  task_role_arn            = each.value.task_role_arn

  container_definitions = jsonencode([
    {
      name      = each.key
      image     = each.value.image
      essential = true

      portMappings = each.value.port > 0 ? [
        {
          containerPort = each.value.port
          protocol      = "tcp"
        }
      ] : []

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.service[each.key].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = each.key
        }
      }

      environment = each.value.environment
      secrets     = each.value.secrets
    }
  ])

  tags = var.tags
}

resource "aws_ecs_service" "this" {
  for_each = { for k, v in var.services : k => v if v.type == "service" }

  name                               = "${var.prefix}-${each.key}"
  cluster                            = aws_ecs_cluster.this.id
  task_definition                    = aws_ecs_task_definition.service[each.key].arn
  desired_count                      = each.value.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  enable_execute_command             = true
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = each.value.subnet_ids
    security_groups  = each.value.security_group_ids
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = each.value.target_group_arn != null ? [1] : []
    content {
      target_group_arn = each.value.target_group_arn
      container_name   = each.key
      container_port   = each.value.port
    }
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = var.tags
}

# Auto Scaling (Service ごとに有効化)
resource "aws_appautoscaling_target" "this" {
  for_each = { for k, v in var.services : k => v if v.type == "service" && v.auto_scaling_enabled }

  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = each.value.min_capacity
  max_capacity       = each.value.max_capacity
}

resource "aws_appautoscaling_policy" "cpu" {
  for_each = { for k, v in var.services : k => v if v.type == "service" && v.auto_scaling_enabled }

  name               = "${var.prefix}-${each.key}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.this[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = each.value.cpu_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
