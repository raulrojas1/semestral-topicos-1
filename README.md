# Proyecto final: tres pipelines DevOps en AWS

Aplicación web (frontend nginx + backend Node/Express) desplegada en ECS Fargate, con tres pipelines de GitHub Actions.

## Estructura

| Carpeta | Contenido |
|---|---|
| `terraform/` | Infraestructura: VPC, ALB, ECR, ECS Fargate, IAM, OIDC de GitHub |
| `aplicacion/` | `frontend/` y `backend/` con sus Dockerfiles, y `docker-compose.yml` para pruebas locales |
| `pipelines/scripts/` | Lógica de los pipelines (bootstrap, build, deploy, smoke test) |
| `.github/workflows/` | Definiciones de los tres pipelines (GitHub exige esta ruta) |

## Arquitectura

```
Internet -> ALB :80 --/api/*--> Target group backend  -> ECS service backend  (Node :3000)
                   \--/------> Target group frontend -> ECS service frontend (nginx :80)
GitHub Actions --OIDC--> IAM roles --> Terraform / ECR / ECS
```

Decisiones:
- **Un solo ALB con ruteo por ruta.** El navegador llama a `/api/...` en el mismo origen, así que no hay CORS ni URLs del backend en el frontend.
- **Subredes públicas sin NAT.** Reduce el costo. Las tareas solo aceptan tráfico del ALB (security group).
- **Credenciales: OIDC, sin claves.** GitHub asume roles IAM acotados al repo y a la rama `main`. Hay dos roles: uno de mínimo privilegio para los pipelines 2 y 3, y otro con AdministratorAccess para Terraform (decisión académica; en producción se acotaría).
- **Imágenes inmutables con tag = SHA del commit.** Permite trazabilidad y rollback exacto.
- **Terraform crea los servicios con 0 tareas y no gestiona la imagen.** El pipeline 3 registra nuevas revisiones de task definition y fija `desired_count` (`ignore_changes` en el servicio).
- **Errores:** circuit breaker de ECS con rollback automático, `aws ecs wait services-stable`, smoke test con reintentos, `concurrency` para evitar ejecuciones simultáneas, validación de existencia de la imagen antes de desplegar.

## Requisitos

AWS CLI, Terraform >= 1.10, Docker, `jq`, una cuenta AWS y un repositorio en GitHub.

## Pasos para reproducir

### 1. Bootstrap (una vez, con credenciales AWS locales)

```bash
bash pipelines/scripts/bootstrap-state.sh        # crea el bucket del estado y terraform/backend.hcl
cd terraform
cp terraform.tfvars.example terraform.tfvars     # editar github_repository = "usuario/repo"
terraform init -backend-config=backend.hcl
terraform apply
```

Este primer `apply` local crea los roles OIDC que los pipelines necesitan. Si la cuenta ya tiene el proveedor OIDC de GitHub, usa `create_github_oidc_provider = false`.

### 2. Configurar GitHub (Settings > Secrets and variables > Actions > Variables)

No hay secretos; todas son variables:

| Variable | Valor |
|---|---|
| `AWS_REGION` | `us-east-1` |
| `AWS_APP_ROLE_ARN` | output `github_app_role_arn` |
| `AWS_TERRAFORM_ROLE_ARN` | output `github_terraform_role_arn` |
| `TF_STATE_BUCKET` | bucket creado por el bootstrap |
| `CREATE_OIDC_PROVIDER` | Opcional. Debe coincidir con `create_github_oidc_provider` de tu `terraform.tfvars` (por defecto `true`) |

### 3. Ejecutar los pipelines

1. **Pipeline 1** (`01 - Infraestructura`): se ejecuta al cambiar `terraform/**` (plan en PR, apply en `main`) o manualmente.
2. **Pipeline 2** (`02 - Construcción y publicación`): al hacer push de `aplicacion/**` a `main`. Publica `devops-final-frontend:<sha>` y `devops-final-backend:<sha>`.
3. **Pipeline 3** (`03 - Despliegue`): se dispara solo al terminar el 2. También manual con un `image_tag` para desplegar o revertir.

Si hiciste push del código antes de configurar las variables del paso 2, esas ejecuciones habrán fallado (sin rol que asumir). Una vez configuradas, lanza el pipeline 2 con **Run workflow** (`workflow_dispatch`) en `main`: al terminar con éxito dispara solo el pipeline 3.

Al terminar, la URL está en el output `app_url` y en el log del smoke test.

> Antes de subir cambios en `terraform/`, ejecuta `terraform fmt -recursive`: el pipeline 1 falla si el formato no es el canónico.

### Prueba local

```bash
cd aplicacion && docker compose up --build    # http://localhost:8080
```

### Limpieza

Ejecuta el pipeline 1 manualmente con `action = destroy`, o `terraform destroy` local. Luego borra el bucket del estado.

## Guion de demo

1. Mostrar `terraform/` y la ejecución del pipeline 1; en la consola AWS: VPC, ALB, ECR, cluster ECS.
2. Cambiar un texto en `aplicacion/frontend/index.html`, hacer push y mostrar el pipeline 2; en ECR, la nueva imagen con el SHA como tag.
3. Mostrar el pipeline 3 y abrir `app_url`; el banner muestra la versión desplegada.
4. Errores: desplegar un tag inexistente (falla con mensaje claro) y explicar el circuit breaker.
5. Credenciales: no hay claves, solo OIDC y variables.

Evidencia de la demo: _(agregar enlace)_
