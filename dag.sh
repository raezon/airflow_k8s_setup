#!/bin/bash
# Créer le dossier dags s'il n'existe pas
mkdir -p dags

# Créer un DAG simple
cat > dags/simple_test.py << 'EOF'
from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime

with DAG(
    "test_simple",
    start_date=datetime(2024, 1, 1),
    schedule_interval=None,
    catchup=False,
) as dag:
    BashOperator(
        task_id="test",
        bash_command='echo "✅ Test Airflow!" && date'
    )
EOF

# Créer le ConfigMap
kubectl create configmap airflow-dags --from-file=dags/