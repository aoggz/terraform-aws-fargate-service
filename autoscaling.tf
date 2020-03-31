resource "aws_appautoscaling_target" "app_scale_target" {
  count              = var.enable_autoscale ? 1 : 0
  service_namespace  = "ecs"
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  max_capacity       = var.task_max_instance_count
  min_capacity       = var.task_count

  depends_on = [
    aws_ecs_service.main
  ]
}

resource "aws_cloudwatch_metric_alarm" "memory_or_cpu_high" {
  count               = var.enable_autoscale ? 1 : 0
  alarm_name          = "${aws_ecs_service.main.name}-Memory-${var.task_scale_out_memory_threshold_percent}-OR-CPU-${var.task_scale_out_cpu_threshold_percent}-High"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  threshold           = "1"
  alarm_description   = "Scale out ${aws_ecs_service.main.name} tasks"
 
  metric_query {
    id          = "e1"
    expression  = "CEIL((cpu-${var.task_scale_out_cpu_threshold_percent})/(100))+CEIL((memory-${var.task_scale_out_memory_threshold_percent})/(100))"
    label       = "CPU or Memory Utilization High"
    return_data = "true"
  }
 
  metric_query {
    id = "cpu"
 
    metric {
      metric_name = "CPUUtilization"
      namespace   = "AWS/ECS"
      period      = var.task_scale_out_alarm_evaluation_period
      stat        = "Average"
      unit        = "Percent"
 
      dimensions = {
        ClusterName = var.ecs_cluster_name
        ServiceName = aws_ecs_service.main.name
      }
    }
  }
 
  metric_query {
    id = "memory"
 
    metric {
      metric_name = "MemoryUtilization"
      namespace   = "AWS/ECS"
      period      = var.task_scale_out_alarm_evaluation_period
      stat        = "Average"
      unit        = "Percent"
 
      dimensions = {
        ClusterName = var.ecs_cluster_name
        ServiceName = aws_ecs_service.main.name
      }
    }
  }

  alarm_actions = var.enable_monitoring ? [aws_appautoscaling_policy.app_out[0].arn, module.notify-slack.this_slack_topic_arn] : [aws_appautoscaling_policy.app_out[0].arn]

  depends_on = [
    aws_appautoscaling_target.app_scale_target[0],
  ]
}

resource "aws_cloudwatch_metric_alarm" "memory_and_cpu_low" {
  count              = var.enable_autoscale ? 1 : 0
  alarm_name          = "${aws_ecs_service.main.name}-Memory-${var.task_scale_in_memory_threshold_percent}-AND-CPU-${var.task_scale_in_cpu_threshold_percent}-Low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  threshold           = "1"
  alarm_description   = "Scale in ${aws_ecs_service.main.name} tasks"
 
  metric_query {
    id          = "e1"
    expression  = "CEIL((cpu-${var.task_scale_in_cpu_threshold_percent})/(100))+CEIL((memory-${var.task_scale_in_memory_threshold_percent})/(100))"
    label       = "CPU and Memory Utilization low"
    return_data = "true"
  }
 
  metric_query {
    id = "cpu"
 
    metric {
      metric_name = "CPUUtilization"
      namespace   = "AWS/ECS"
      period      = var.task_scale_in_alarm_evaluation_period
      stat        = "Average"
      unit        = "Percent"
 
      dimensions = {
        ClusterName = var.ecs_cluster_name
        ServiceName = aws_ecs_service.main.name
      }
    }
  }
 
  metric_query {
    id = "memory"
 
    metric {
      metric_name = "MemoryUtilization"
      namespace   = "AWS/ECS"
      period      = var.task_scale_in_alarm_evaluation_period
      stat        = "Average"
      unit        = "Percent"
 
      dimensions = {
        ClusterName = var.ecs_cluster_name
        ServiceName = aws_ecs_service.main.name
      }
    }
  }

    alarm_actions = var.enable_monitoring ? [aws_appautoscaling_policy.app_in[0].arn, module.notify-slack.this_slack_topic_arn] : [aws_appautoscaling_policy.app_in[0].arn]

  depends_on = [
    aws_appautoscaling_target.app_scale_target[0],
  ]
}

resource "aws_appautoscaling_policy" "app_out" {
  count              = var.enable_autoscale ? 1 : 0
  name               = "app-scale-out"
  service_namespace  = aws_appautoscaling_target.app_scale_target[0].service_namespace
  resource_id        = aws_appautoscaling_target.app_scale_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.app_scale_target[0].scalable_dimension

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = var.task_scale_out_cooldown_period
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }

  depends_on = [
    aws_appautoscaling_target.app_scale_target[0],
  ]
}

resource "aws_appautoscaling_policy" "app_in" {
  count              = var.enable_autoscale ? 1 : 0
  name               = "app-scale-in"
  service_namespace  = aws_appautoscaling_target.app_scale_target[0].service_namespace
  resource_id        = aws_appautoscaling_target.app_scale_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.app_scale_target[0].scalable_dimension

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = var.task_scale_in_cooldown_period
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }

  depends_on = [
    aws_appautoscaling_target.app_scale_target[0],
  ]
}