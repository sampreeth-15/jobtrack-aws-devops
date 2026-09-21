resource "aws_vpc" "jobtrack" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "jobtrack-vpc"
  }
}

resource "aws_internet_gateway" "jobtrack" {
  vpc_id = aws_vpc.jobtrack.id

  tags = {
    Name = "jobtrack-igw"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.jobtrack.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "jobtrack-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.jobtrack.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "jobtrack-public-b"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.jobtrack.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "jobtrack-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.jobtrack.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "jobtrack-private-b"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.jobtrack.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jobtrack.id
  }

  tags = {
    Name = "jobtrack-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.jobtrack.id

  tags = {
    Name = "jobtrack-private-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "jobtrack-nat-eip"
  }
}

resource "aws_nat_gateway" "jobtrack" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "jobtrack-nat"
  }

  depends_on = [
    aws_internet_gateway.jobtrack
  ]
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.jobtrack.id
}

resource "aws_security_group" "alb" {
  name        = "jobtrack-alb-sg"
  description = "Security group for JobTrack ALB"
  vpc_id      = aws_vpc.jobtrack.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jobtrack-alb-sg"
  }
}

resource "aws_security_group" "ecs" {
  name        = "jobtrack-ecs-sg"
  description = "Security group for JobTrack ECS"
  vpc_id      = aws_vpc.jobtrack.id

  ingress {
    description     = "Flask application from ALB"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jobtrack-ecs-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "jobtrack-rds-sg"
  description = "Security group for JobTrack PostgreSQL"
  vpc_id      = aws_vpc.jobtrack.id

  ingress {
    description     = "PostgreSQL from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jobtrack-rds-sg"
  }
}

resource "aws_db_subnet_group" "jobtrack" {
  name = "jobtrack-db-subnet-group"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  tags = {
    Name = "jobtrack-db-subnet-group"
  }
}

resource "aws_db_instance" "jobtrack" {
  identifier = "jobtrack-postgres"

  engine         = "postgres"
  engine_version = "16"

  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "jobtrack"
  username = "jobtrack_admin"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.jobtrack.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible     = false
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 1

  tags = {
    Name = "jobtrack-postgres"
  }
}

resource "aws_ecs_cluster" "jobtrack" {
  name = "jobtrack-cluster"

  tags = {
    Name = "jobtrack-cluster"
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "jobtrack-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "jobtrack" {
  name              = "/ecs/jobtrack"
  retention_in_days = 7

  tags = {
    Name = "jobtrack-logs"
  }
}

data "aws_secretsmanager_secret" "database" {
  name = "jobtrack/database"
}

data "aws_secretsmanager_secret" "flask_secret" {
  name = "jobtrack/flask-secret"
}
resource "aws_ecs_task_definition" "jobtrack" {
  family                   = "jobtrack"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "jobtrack"
      image     = "100247989016.dkr.ecr.ap-south-1.amazonaws.com/jobtrack:gunicorn"
      essential = true

      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
          protocol      = "tcp"
        }
      ]

             
         environment = [
  {
    name  = "CREATE_DB"
    value = "true"
  }]

secrets = [
  {
    name      = "DATABASE_URL"
   valueFrom = "${data.aws_secretsmanager_secret.database.arn}"
  },
  {
    name      = "SECRET_KEY"
    valueFrom = "${data.aws_secretsmanager_secret.flask_secret.arn}"
  }
]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "python -c \"import urllib.request; urllib.request.urlopen('http://localhost:5000/health')\" || exit 1"
        ]

        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.jobtrack.name
          "awslogs-region"        = "ap-south-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_lb" "jobtrack" {
  name               = "jobtrack-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  tags = {
    Name = "jobtrack-alb"
  }
}

resource "aws_lb_target_group" "jobtrack" {
  name        = "jobtrack-tg"
  port        = 5000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.jobtrack.id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    port                = "5000"

    healthy_threshold   = 2
    unhealthy_threshold = 3

    timeout  = 5
    interval = 30

    matcher = "200"
  }

  tags = {
    Name = "jobtrack-target-group"
  }
}

resource "aws_lb_listener" "jobtrack" {
  load_balancer_arn = aws_lb.jobtrack.arn

  port     = 80
  protocol = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jobtrack.arn
  }
}

resource "aws_ecs_service" "jobtrack" {
  name            = "jobtrack-service"
  cluster         = aws_ecs_cluster.jobtrack.id
  task_definition = aws_ecs_task_definition.jobtrack.arn

  desired_count = 1

  launch_type = "FARGATE"

  network_configuration {
    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    security_groups = [
      aws_security_group.ecs.id
    ]

    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.jobtrack.arn
    container_name   = "jobtrack"
    container_port   = 5000
  }

  depends_on = [
    aws_lb_listener.jobtrack
  ]

  tags = {
    Name = "jobtrack-service"
  }
}
