#!/usr/bin/env bash
# Construye frontend y backend, los etiqueta y publica en ECR.
# Uso: build-and-push.sh <image_tag>
# Entorno: AWS_REGION, PROJECT_NAME (opcional). Requiere sesión AWS activa y Docker.
set -euo pipefail

TAG="${1:?Uso: build-and-push.sh <image_tag>}"
REGION="${AWS_REGION:-us-east-1}"
PROJECT="${PROJECT_NAME:-devops-final}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"

for component in backend frontend; do
  REPO="${PROJECT}-${component}"
  IMAGE="${REGISTRY}/${REPO}:${TAG}"

  # Los repos son inmutables: si el tag ya existe (re-ejecución), no se vuelve a publicar.
  if aws ecr describe-images --region "$REGION" --repository-name "$REPO" \
       --image-ids imageTag="$TAG" >/dev/null 2>&1; then
    echo "[$component] $TAG ya existe en ECR, se omite"
    continue
  fi

  echo "[$component] construyendo $IMAGE"
  docker build --platform linux/amd64 --build-arg "APP_VERSION=${TAG}" \
    -t "$IMAGE" "$ROOT/aplicacion/$component"
  docker push "$IMAGE"
done

echo "Imágenes publicadas con tag $TAG"
