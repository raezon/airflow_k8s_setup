from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from datetime import datetime

# Définition du DAG
with DAG(
    "test_simple",  # Nom du DAG
    start_date=datetime(2024, 1, 1),  # Date de début
    schedule_interval="@daily",  # Exécution quotidienne
    catchup=False,  # Ne pas rattraper les exécutions passées
    tags=["test"],  # Tags pour le filtrage
) as dag:

    # Tâche 1: Afficher la date
    task1 = BashOperator(
        task_id="afficher_date",
        bash_command="echo '📅 Date actuelle: $(date)'",
    )

    # Tâche 2: Message simple Python
    def dire_bonjour():
        print("🎉 Bonjour Airflow! Tout fonctionne bien!")
        return "Succès"

    task2 = PythonOperator(
        task_id="dire_bonjour",
        python_callable=dire_bonjour,
    )

    # Tâche 3: Vérifier l'environnement
    task3 = BashOperator(
        task_id="verifier_environnement",
        bash_command="echo '🐍 Python version:' && python --version && echo '📁 Dossier courant:' && pwd",
    )

    # Ordre d'exécution
    task1 >> task2 >> task3