### Déploiement manuel

1. **Appliquer tous les services et déploiements Kubernetes :**

```bash
kubectl apply -f airflow.all.yaml
```

Cela va créer :

* **Déploiements :** `postgres`, `rabbitmq`, `airflow-webserver`, `airflow-scheduler`, `airflow-flower`, `airflow-worker`
* **Services :** `postgres`, `rabbitmq`, `airflow-webserver`, `airflow-flower`

---

2. **Lancer le script pour les port-forwarding** afin d’accéder aux dashboards depuis ton poste :

```bash
./start-port-forwarding.sh
```

* Ceci va forwarder les ports nécessaires pour accéder à **Airflow Web UI** (par défaut `http://localhost:8080`) et **Flower** (monitoring des workers Celery).

---

3. **Optionnel : Exécuter un DAG de test** pour vérifier que tout fonctionne :

```bash
kubectl exec <airflow-webserver-pod> -- airflow dags backfill tutorial -s 2015-05-01 -e 2015-06-01
```

---

4. **Scaler les workers** si besoin :

* Modifier le nombre de `replicas` dans le `Deployment` des workers dans `airflow.all.yaml`
* Appliquer à nouveau avec :

```bash
kubectl apply -f airflow.all.yaml
```

