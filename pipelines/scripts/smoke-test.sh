#!/usr/bin/env bash
# Verifica que frontend y backend responden a través del ALB y que el backend corre el tag esperado.
# Uso: smoke-test.sh [image_tag]
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
PROJECT="${PROJECT_NAME:-devops-final}"
EXPECTED_TAG="${1:-}"

DNS="$(aws elbv2 describe-load-balancers --region "$REGION" --names "${PROJECT}-alb" \
  --query 'LoadBalancers[0].DNSName' --output text)"
URL="http://${DNS}"
echo "URL: $URL"

retry() { # reintenta mientras el ALB registra los targets
  local n=0
  until "$@"; do
    n=$((n + 1)); [ "$n" -ge 12 ] && return 1
    sleep 10
  done
}

# Se guarda la respuesta en una variable: con `pipefail`, `curl | grep -q` puede fallar
# de forma intermitente si grep cierra la tubería antes de que curl termine de escribir.
check_frontend() { local body; body="$(curl -fsS --max-time 10 "$URL/")" && grep -q "Demo DevOps" <<< "$body"; }
check_backend()  { local body; body="$(curl -fsS --max-time 10 "$URL/api/health")" && grep -q '"ok"' <<< "$body"; }

retry check_frontend && echo "OK frontend" || { echo "FALLO frontend" >&2; exit 1; }
retry check_backend  && echo "OK backend /api/health" || { echo "FALLO backend" >&2; exit 1; }

if [ -n "$EXPECTED_TAG" ]; then
  VERSION="$(curl -fsS "$URL/api/info" | jq -r .version)"
  [ "$VERSION" = "$EXPECTED_TAG" ] || { echo "Versión desplegada $VERSION != $EXPECTED_TAG" >&2; exit 1; }
  echo "OK versión $VERSION"
fi
echo "Aplicación operativa en $URL"
