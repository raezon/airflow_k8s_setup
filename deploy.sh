#!/bin/bash

echo "🔨 Déploiement d'Airflow sur Kubernetes..."

# Vérification que le dossier DAGs existe
echo "📁 Vérification du dossier DAGs..."
if [ ! -d "/c/projects/helm-airflow/kube-airflow/dags" ]; then
    echo "❌ Dossier DAGs introuvable. Création..."
    mkdir -p /c/projects/helm-airflow/kube-airflow/dags
fi

# Application de la configuration
echo "🚀 Application de la configuration Kubernetes..."
kubectl apply -f airflow.yaml

echo "⏳ Attente du déploiement..."
sleep 30

# Vérification du statut
echo "📊 Statut des pods:"
kubectl get pods

echo "🌐 URLs d'accès:"
echo "Airflow Web: http://localhost:32080"
echo "Flower:      http://localhost:32081"
echo "RabbitMQ:    http://localhost:31672"

echo "✅ Déploiement terminé!"