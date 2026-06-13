#!/usr/bin/env bash
# Seed першої версії моделі: docker build + push + train Job у кластері +
# bump image.tag у helm/values.yaml. Запускати один раз після того, як
# `kubectl get applications -A` показує MLflow Healthy.
#
# Передумови:
#   - docker login до GitLab Container Registry (один раз):
#       docker login registry.gitlab.com
#   - kubectl сконфігуровано на EKS:
#       aws eks update-kubeconfig --region eu-central-1 --name mlops-eks-cluster
#
# Використання:
#   ./scripts/seed-model.sh
#
# Опційні env-vars:
#   REGISTRY_PREFIX  — default registry.gitlab.com/cryptophobic/mlops-train-automation
#   TAG              — default seed-<unix-ts>
set -euo pipefail

REGISTRY_PREFIX="${REGISTRY_PREFIX:-registry.gitlab.com/cryptophobic/mlops-train-automation}"
TAG="${TAG:-seed-$(date +%s)}"
IMAGE="${REGISTRY_PREFIX}/digits-inference:${TAG}"

echo "=== 1. Build image ${IMAGE} ==="
docker build -t "${IMAGE}" .

echo "=== 2. Push to registry ==="
docker push "${IMAGE}"

echo "=== 3. Submit train Job ==="
JOB_NAME=$(sed "s|__IMAGE__|${IMAGE}|g" model/train-job.yaml \
           | kubectl create -f - -o jsonpath='{.metadata.name}')
echo "Started: ${JOB_NAME}"

echo "=== 4. Wait for training completion ==="
if ! kubectl -n inference wait --for=condition=complete --timeout=600s "job/${JOB_NAME}"; then
  echo "Training job failed; tail of logs:"
  kubectl -n inference logs "job/${JOB_NAME}" --tail=200 || true
  exit 1
fi
kubectl -n inference logs "job/${JOB_NAME}" --tail=30

echo "=== 5. Bump helm/values.yaml ==="
sed -i.bak "s|^  tag: .*|  tag: \"${TAG}\"|" helm/values.yaml
rm -f helm/values.yaml.bak
grep "^  tag:" helm/values.yaml

cat <<EOF

Seed done. Now commit & push:

  git add helm/values.yaml
  git commit -m "seed: initial model image ${TAG}"
  git push origin final-project

ArgoCD will then roll the inference deployment to image ${TAG} and the
pod will load digits-classifier@Production at startup.
EOF