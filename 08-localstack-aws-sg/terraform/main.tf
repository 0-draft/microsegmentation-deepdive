resource "aws_vpc" "shop" {
  cidr_block = "10.20.0.0/16"
  tags = {
    Name = "ms08-shop"
  }
}

resource "aws_subnet" "web" {
  vpc_id            = aws_vpc.shop.id
  cidr_block        = "10.20.1.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "ms08-web" }
}

resource "aws_subnet" "app" {
  vpc_id            = aws_vpc.shop.id
  cidr_block        = "10.20.2.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "ms08-app" }
}

resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Web tier: HTTP from anywhere"
  vpc_id      = aws_vpc.shop.id

  ingress {
    description = "HTTP from internet"
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

  tags = { Name = "ms08-web-sg" }
}

resource "aws_security_group" "app" {
  name        = "app-sg"
  description = "App tier: receives :8080 only from web-sg"
  vpc_id      = aws_vpc.shop.id

  ingress {
    description     = "HTTP from web tier"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ms08-app-sg" }
}

resource "aws_security_group" "db" {
  name        = "db-sg"
  description = "DB tier: receives :5432 only from app-sg"
  vpc_id      = aws_vpc.shop.id

  ingress {
    description     = "Postgres from app tier"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ms08-db-sg" }
}

output "vpc_id"    { value = aws_vpc.shop.id }
output "web_sg_id" { value = aws_security_group.web.id }
output "app_sg_id" { value = aws_security_group.app.id }
output "db_sg_id"  { value = aws_security_group.db.id }
