variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "devops-final"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "backend_port" {
  type    = number
  default = 3000
}

variable "frontend_port" {
  type    = number
  default = 80
}

variable "github_repository" {
  description = "Repositorio con acceso OIDC, formato org/repo"
  type        = string
}

variable "github_branch" {
  description = "Rama autorizada para asumir los roles de GitHub Actions"
  type        = string
  default     = "main"
}

variable "create_github_oidc_provider" {
  description = "false si el proveedor OIDC de GitHub ya existe en la cuenta"
  type        = bool
  default     = true
}

variable "task_cpu" {
  type    = number
  default = 256
}

variable "task_memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  description = "Cantidad inicial de tareas. 0 hasta que existan imágenes en ECR; el pipeline 3 lo sube."
  type        = number
  default     = 0
}
