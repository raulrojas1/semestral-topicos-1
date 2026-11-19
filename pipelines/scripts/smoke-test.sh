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

check_frontend() { curl -fsS "$URL/" | grep -q "Demo DevOps"; }
check_backend()  { curl -fsS "$URL/api/health" | grep -q '"ok"'; }

retry check_frontend && echo "OK frontend" || { echo "FALLO frontend" >&2; exit 1; }
retry check_backend  && echo "OK backend /api/health" || { echo "FALLO backend" >&2; exit 1; }

if [ -n "$EXPECTED_TAG" ]; then
  VERSION="$(curl -fsS "$URL/api/info" | jq -r .version)"
  [ "$VERSION" = "$EXPECTED_TAG" ] || { echo "Versión desplegada $VERSION != $EXPECTED_TAG" >&2; exit 1; }
  echo "OK versión $VERSION"
fi
echo "Aplicación operativa en $URL"
