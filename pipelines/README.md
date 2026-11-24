# Pipelines

Los tres pipelines están implementados con **GitHub Actions**. GitHub solo ejecuta workflows ubicados en
`.github/workflows/`, así que las definiciones están allí; la lógica de cada paso está en los scripts de
`pipelines/scripts/` y los workflows solo los invocan.

| # | Definición (workflow) | Script(s) | Disparador |
|---|---|---|---|
| 1 | [`01-infraestructura.yml`](../.github/workflows/01-infraestructura.yml) | `scripts/bootstrap-state.sh` (una sola vez, local) | Cambios en `terraform/**`: `plan` en PR, `apply` en `main`. Manual: `apply` o `destroy` |
| 2 | [`02-build-publicar.yml`](../.github/workflows/02-build-publicar.yml) | `scripts/build-and-push.sh` | Push a `main` con cambios en `aplicacion/**`. En PR solo valida el build |
| 3 | [`03-despliegue.yml`](../.github/workflows/03-despliegue.yml) | `scripts/deploy.sh`, `scripts/smoke-test.sh` | Automático al terminar bien el pipeline 2. Manual con un `image_tag` para desplegar o revertir |

## Scripts

| Script | Qué hace |
|---|---|
| `bootstrap-state.sh` | Crea el bucket S3 del estado de Terraform (versionado, cifrado, sin acceso público) y genera `terraform/backend.hcl` |
| `build-and-push.sh <tag>` | Construye `backend` y `frontend`, los etiqueta con el SHA corto del commit y los publica en ECR. Omite los tags que ya existen (repos inmutables) |
| `deploy.sh <tag>` | Verifica que las imágenes existan, registra una nueva task definition por servicio, actualiza ECS, espera estabilidad y comprueba que el servicio no fue revertido por el circuit breaker |
| `smoke-test.sh [tag]` | Consulta el ALB con reintentos: frontend, `/api/health` y que `/api/info` informe el tag desplegado |

## Credenciales

No hay claves de acceso ni secretos. Los workflows asumen roles IAM por OIDC y solo usan variables
no sensibles de GitHub (`AWS_REGION`, `TF_STATE_BUCKET`, `AWS_APP_ROLE_ARN`, `AWS_TERRAFORM_ROLE_ARN`).
Ver el `README.md` de la raíz para la configuración paso a paso.
