#!/bin/bash
echo "🌐 Démarrage du port forwarding..."

# Airflow Webserver
echo "➡️  Airflow UI: http://localhost:8080"
kubectl port-forward service/web 8080:8080 &

# Flower
echo "➡️  Flower Monitoring: http://localhost:5555" 
kubectl port-forward service/flower 5555:5555 &

# RabbitMQ (optionnel)
echo "➡️  RabbitMQ Management: http://localhost:15672"
kubectl port-forward service/rabbitmq 15672:15672 &

echo "✅ Tous les services sont accessibles:"
echo "   - Airflow: http://localhost:8080 (admin/admin)"
echo "   - Flower: http://localhost:5555"
echo "   - RabbitMQ: http://localhost:15672 (airflow/airflow)"

# Attendre que l'utilisateur appuie sur une touche
read -p "Appuyez sur Entrée pour arrêter le port forwarding..."
pkill -f "kubectl port-forward"