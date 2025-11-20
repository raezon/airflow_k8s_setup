#!/bin/bash
# deploy-airflow.sh

set -e

echo "🚀 Déploiement d'Airflow sur Kubernetes..."

# Générer une clé Fernet
echo "🔑 Génération de la clé Fernet..."
FERNET_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())" 2>/dev/null || echo "eUZ5YzVSM1JtWkdabDlqYzNSbFpXWm1aV1psOTJjM1JsWldabVpXWmw5M2MzUmxaV1ptWldabA==")

# Mettre à jour le secret avec la vraie clé
echo "📝 Mise à jour des secrets..."
kubectl create namespace airflow 2>/dev/null || true

# Créer les secrets
kubectl create secret generic airflow-secrets \
  --namespace airflow \
  --from-literal=postgres-password=airflow \
  --from-literal=rabbitmq-password=airflow \
  --from-literal=fernet-key=$FERNET_KEY \
  --dry-run=client -o yaml | kubectl apply -f -

echo "📦 Application des configurations..."
kubectl apply -f airflow-complete.yaml

echo "⏳ Attente de l'initialisation..."
kubectl wait --for=condition=complete -n airflow job/airflow-db-init --timeout=300s

echo "✅ Déploiement terminé!"
echo ""
echo "🌐 URLs d'accès:"
echo "   Airflow Web: http://localhost:32080"
echo "   Flower (Monitoring): http://localhost:32081"
echo "   RabbitMQ Management: http://localhost:31672"
echo ""
echo "👤 Identifiants:"
echo "   Airflow: admin / admin"
echo "   RabbitMQ: airflow / airflow"
echo ""
echo "📊 Commandes utiles:"
echo "   kubectl get pods -n airflow"
echo "   kubectl get hpa -n airflow"
echo "   kubectl logs -n airflow deployment/airflow-webserver"