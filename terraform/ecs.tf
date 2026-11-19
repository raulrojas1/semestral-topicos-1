data "aws_caller_identity" "current" {}

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

locals {
  services = {
    frontend = { port = var.frontend_port, tg = aws_lb_target_group.frontend.arn }
    backend  = { port = var.backend_port, tg = aws_lb_target_group.backend.arn }
  }
}

resource "aws_cloudwatch_log_group" "app" {
  for_each          = local.services
  name              = "/ecs/${var.project_name}-${each.key}"
  retention_in_days = 7
}

# Task definition inicial. Apunta a :bootstrap (no existe); el pipeline 3 registra
# revisiones nuevas con la imagen real y Terraform las ignora (ver ignore_changes del servicio).
resource "aws_ecs_task_definition" "app" {
  for_each                 = local.services
  family                   = "${var.project_name}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name         = each.key
    image        = "${aws_ecr_repository.app[each.key].repository_url}:bootstrap"
    essential    = true
    portMappings = [{ containerPort = each.value.port, protocol = "tcp" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app[each.key].name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = each.key
      }
    }
  }])
}

resource "aws_ecs_service" "app" {
  for_each        = local.services
  name            = "${var.project_name}-${each.key}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app[each.key].arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  health_check_grace_period_seconds = 30

  deployment_circuit_breaker {
    enable   = true
    rollback = true # si el despliegue falla, vuelve a la revisión anterior
  }

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = each.value.tg
    container_name   = each.key
    container_port   = each.value.port
  }

  depends_on = [aws_lb_listener.http]

  # El pipeline 3 gestiona la task definition y el desired_count.
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}
