#!/usr/bin/env bash
# Despliega en ECS las imágenes con el tag indicado: toma la task definition vigente de cada
# servicio, cambia la imagen, registra una revisión nueva y actualiza el servicio.
# Uso: deploy.sh <image_tag>
# Requiere: aws cli, jq.
set -euo pipefail

TAG="${1:?Uso: deploy.sh <image_tag>}"
REGION="${AWS_REGION:-us-east-1}"
PROJECT="${PROJECT_NAME:-devops-final}"
CLUSTER="${PROJECT}-cluster"
DESIRED="${DESIRED_COUNT:-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
DEPLOYED="" # líneas "componente=arn_task_definition" para verificar al final

for component in backend frontend; do
  SERVICE="${PROJECT}-${component}"
  IMAGE="${REGISTRY}/${PROJECT}-${component}:${TAG}"

  # Falla pronto y con un mensaje claro si la imagen no está publicada.
  aws ecr describe-images --region "$REGION" --repository-name "${PROJECT}-${component}" \
    --image-ids imageTag="$TAG" >/dev/null \
    || { echo "ERROR: $IMAGE no existe en ECR. Ejecuta antes el pipeline 2." >&2; exit 1; }

  CURRENT_TD="$(aws ecs describe-services --region "$REGION" --cluster "$CLUSTER" \
    --services "$SERVICE" --query 'services[0].taskDefinition' --output text)"

  NEW_TD_JSON="$(aws ecs describe-task-definition --region "$REGION" --task-definition "$CURRENT_TD" \
    --query taskDefinition --output json \
    | jq --arg image "$IMAGE" '
        .containerDefinitions[0].image = $image
        | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities,
              .registeredAt, .registeredBy)')"

  NEW_TD_ARN="$(aws ecs register-task-definition --region "$REGION" --cli-input-json "$NEW_TD_JSON" \
    --query taskDefinition.taskDefinitionArn --output text)"
  echo "[$component] task definition: $NEW_TD_ARN"
  DEPLOYED+="${component}=${NEW_TD_ARN}"$'\n'

  aws ecs update-service --region "$REGION" --cluster "$CLUSTER" --service "$SERVICE" \
    --task-definition "$NEW_TD_ARN" --desired-count "$DESIRED" >/dev/null
done

echo "Esperando a que los servicios estén estables..."
if ! aws ecs wait services-stable --region "$REGION" --cluster "$CLUSTER" \
     --services "${PROJECT}-backend" "${PROJECT}-frontend"; then
  echo "ERROR: los servicios no se estabilizaron (el circuit breaker revierte al despliegue anterior)." >&2
  aws ecs describe-services --region "$REGION" --cluster "$CLUSTER" \
    --services "${PROJECT}-backend" "${PROJECT}-frontend" \
    --query 'services[].{name:serviceName,events:events[:3].message}' --output json >&2
  exit 1
fi

# `services-stable` también termina bien cuando el circuit breaker revierte al despliegue anterior
# (el servicio vuelve a ser estable con la revisión vieja). Se comprueba que cada servicio quedó
# realmente en la task definition recién registrada.
while IFS='=' read -r component expected_td; do
  [ -n "$component" ] || continue
  ACTIVE_TD="$(aws ecs describe-services --region "$REGION" --cluster "$CLUSTER" \
    --services "${PROJECT}-${component}" --query 'services[0].taskDefinition' --output text)"
  if [ "$ACTIVE_TD" != "$expected_td" ]; then
    echo "ERROR: [$component] el despliegue fue revertido (activa: $ACTIVE_TD, esperada: $expected_td)." >&2
    exit 1
  fi
done <<< "$DEPLOYED"

echo "Despliegue completado con tag $TAG"
