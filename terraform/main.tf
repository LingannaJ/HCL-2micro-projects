provider "aws" {
  region = "us-east-1"
}

# VPC with subnets
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "hackathon-vpc"
  cidr   = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway = true
}

# ECS Cluster
resource "aws_ecs_cluster" "hackathon_cluster" {
  name = "hackathon-ecs-cluster"
}

# IAM Role for ECS tasks
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_task_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "ecs_task_execution_policy" {
  name       = "ecs_task_execution_policy_attachment"
  roles      = [aws_iam_role.ecs_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Security Group for ECS
resource "aws_security_group" "ecs_security_group" {
  name        = "ecs-sg"
  description = "Allow traffic to ECS services"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for ALB
resource "aws_security_group" "alb_security_group" {
  name        = "alb-sg"
  description = "Allow HTTP traffic to ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group Rule for ALB to ECS
resource "aws_security_group_rule" "ecs_allow_alb" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3001
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs_security_group.id
  source_security_group_id = aws_security_group.alb_security_group.id
}

# Application Load Balancer
resource "aws_lb" "app_alb" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_security_group.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false
}

# Target Group for Patient Service
resource "aws_lb_target_group" "patient_target_group" {
  name        = "patient-target-group"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    interval            = 30
    path                = "/health"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299"
  }
}

# Target Group for Appointment Service
resource "aws_lb_target_group" "appointment_target_group" {
  name        = "appointment-target-group"
  port        = 3001
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    interval            = 30
    path                = "/health"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299"
  }
}

# Listener for ALB
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.patient_target_group.arn
  }
}

# Listener Rule for Appointment Service
resource "aws_lb_listener_rule" "appointment_listener_rule" {
  listener_arn = aws_lb_listener.app_listener.arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/appointments/*", "/appointments"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.appointment_target_group.arn
  }
}

# ECS Service for Patient Service
resource "aws_ecs_service" "patient_service" {
  name            = "patient-service"
  cluster         = aws_ecs_cluster.hackathon_cluster.id
  task_definition = aws_ecs_task_definition.patient_service.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.ecs_security_group.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.patient_target_group.arn
    container_name   = "patient-service-container"
    container_port   = 3000
  }
}

# ECS Service for Appointment Service
resource "aws_ecs_service" "appointment_service" {
  name            = "appointment-service"
  cluster         = aws_ecs_cluster.hackathon_cluster.id
  task_definition = aws_ecs_task_definition.appointment_service.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.ecs_security_group.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.appointment_target_group.arn
    container_name   = "appointment-service-container"
    container_port   = 3001
  }
}

# ECR Repositories
resource "aws_ecr_repository" "patient_service" {
  name = "patient-service-repo"
  force_delete = true
}

resource "aws_ecr_repository" "appointment_service" {
  name = "appointment-service-repo"
  force_delete = true
}

# ECS Task Definitions
resource "aws_ecs_task_definition" "patient_service" {
  family                   = "patient-service-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name        = "patient-service-container"
    image       = "767397768520.dkr.ecr.us-east-1.amazonaws.com/patient-service-repo:latest"
    cpu         = 256
    memory      = 512
    portMappings = [
      {
        containerPort = 3000
        hostPort      = 3000
      }
    ]
  }])
}

resource "aws_ecs_task_definition" "appointment_service" {
  family                   = "appointment-service-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name        = "appointment-service-container"
    image       = "767397768520.dkr.ecr.us-east-1.amazonaws.com/appointment-service-repo:latest"
    cpu         = 256
    memory      = 512
    portMappings = [
      {
        containerPort = 3001
        hostPort      = 3001
      }
    ]
  }])
}
