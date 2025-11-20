from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime

with DAG(
    "test_fixed",
    start_date=datetime(2024, 1, 1),
    schedule_interval=None,
    catchup=False,
) as dag:
    BashOperator(
        task_id="test",
        bash_command='echo "✅ CONFIGMAP FIXED!" && date'
    )
