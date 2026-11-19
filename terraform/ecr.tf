resource "aws_ecr_repository" "app" {
  for_each             = toset(["frontend", "backend"])
  name                 = "${var.project_name}-${each.key}"
  image_tag_mutability = "IMMUTABLE" # cada commit tiene su propio tag; no se sobrescribe
  force_delete         = true        # permite terraform destroy aunque haya imágenes

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  for_each   = aws_ecr_repository.app
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Conservar las ultimas 15 imagenes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 15
      }
      action = { type = "expire" }
    }]
  })
}
