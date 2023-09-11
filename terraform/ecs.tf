resource "aws_ecs_cluster" "test" {
  name = "test"
}

resource "aws_ecs_cluster_capacity_providers" "provider" {
  cluster_name       = aws_ecs_cluster.test.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/logs/test/api"
  retention_in_days = 1
}

resource "aws_iam_role" "ecs_task_execution_role" {
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "ecs-tasks.amazonaws.com"
          }
          Sid = ""
        },
      ]
      Version = "2012-10-17"
    }
  )
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
  ]
  description = "Allows ECS tasks to call AWS services on your behalf."
  name        = "ecsTaskExecutionRole"
  path        = "/"
}

resource "aws_ecs_task_definition" "api" {
  family                   = "api"
  container_definitions    = file("./container_definitions.json")
  cpu                      = 256
  memory                   = 512
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  requires_compatibilities = ["FARGATE"]
}

resource "aws_ecs_service" "ecs_service" {
  name = "url-shorten-api"
  capacity_provider_strategy {
    base              = 1
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }
  cluster       = aws_ecs_cluster.test.id
  desired_count = 0
  network_configuration {
    subnets = [
      aws_subnet.private["ap-northeast-1a"].id,
      aws_subnet.private["ap-northeast-1c"].id,
    ]
    security_groups  = [aws_security_group.api.id]
    assign_public_ip = false
  }
  task_definition = aws_ecs_task_definition.api.arn
  tags = {
    "Environment" = "test"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.alb_target_group_api.arn
    container_name   = "api"
    container_port   = 80
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count,
    ]
  }
}

# alb
resource "aws_alb" "alb" {
  name               = "api"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_security_group.id]
  subnets = [
    aws_subnet.public["ap-northeast-1a"].id,
    aws_subnet.public["ap-northeast-1c"].id,
  ]
}

resource "aws_lb_target_group" "alb_target_group_api" {
  name        = "api"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id
  health_check {
    enabled  = true
    path     = "/healthcheck"
    port     = 80
    protocol = "HTTP"
  }
}

resource "aws_lb_listener" "alb_listner" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_group_api.arn
  }
}

resource "aws_ecr_repository" "api" {
  name                 = "api"
  image_tag_mutability = "MUTABLE"

  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

output "alb_endpoint" {
  value = aws_alb.alb.dns_name
}



