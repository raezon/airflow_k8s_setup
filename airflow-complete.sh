# 1. Sauvegarder le fichier YAML complet
cat > airflow-complete.yaml << 'EOF'
# airflow-complete.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: airflow
  labels:
    name: airflow
---
# Secrets pour les mots de passe
apiVersion: v1
kind: Secret
metadata:
  name: airflow-secrets
  namespace: airflow
type: Opaque
data:
  postgres-password: YWlyZmxvdw==  # airflow
  rabbitmq-password: YWlyZmxvdw==  # airflow
  fernet-key: eUZ5YzVSM1JtWkdabDlqYzNSbFpXWm1aV1psOTJjM1JsWldabVpXWmw5M2MzUmxaV1ptWldabA==  # Généré dynamiquement
---
# Service PostgreSQL
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: airflow
  labels:
    app: airflow
    tier: database
spec:
  type: ClusterIP
  selector:
    app: airflow
    tier: database
  ports:
    - name: postgres
      port: 5432
      targetPort: 5432
      protocol: TCP
---
# Service RabbitMQ
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq
  namespace: airflow
  labels:
    app: airflow
    tier: message-broker
spec:
  type: ClusterIP
  selector:
    app: airflow
    tier: message-broker
  ports:
    - name: amqp
      port: 5672
      targetPort: 5672
      protocol: TCP
    - name: management
      port: 15672
      targetPort: 15672
      protocol: TCP
---
# Service Web (Airflow Webserver)
apiVersion: v1
kind: Service
metadata:
  name: airflow-webserver
  namespace: airflow
  labels:
    app: airflow
    tier: webserver
spec:
  type: NodePort
  selector:
    app: airflow
    tier: webserver
  ports:
    - name: http
      port: 8080
      targetPort: 8080
      nodePort: 32080
      protocol: TCP
---
# Service Flower (Monitoring Celery)
apiVersion: v1
kind: Service
metadata:
  name: airflow-flower
  namespace: airflow
  labels:
    app: airflow
    tier: flower
spec:
  type: NodePort
  selector:
    app: airflow
    tier: flower
  ports:
    - name: flower
      port: 5555
      targetPort: 5555
      nodePort: 32081
      protocol: TCP
---
# Service Scheduler
apiVersion: v1
kind: Service
metadata:
  name: airflow-scheduler
  namespace: airflow
  labels:
    app: airflow
    tier: scheduler
spec:
  type: ClusterIP
  selector:
    app: airflow
    tier: scheduler
  ports:
    - name: scheduler
      port: 8793
      targetPort: 8793
      protocol: TCP
---
# ConfigMap pour la configuration Airflow
apiVersion: v1
kind: ConfigMap
metadata:
  name: airflow-config
  namespace: airflow
data:
  airflow.cfg: |
    [core]
    executor = CeleryExecutor
    dags_folder = /opt/airflow/dags
    load_examples = False
    fernet_key = ${FERNET_KEY}
    sql_alchemy_conn = postgresql+psycopg2://airflow:airflow@postgres:5432/airflow
    
    [celery]
    broker_url = amqp://airflow:airflow@rabbitmq:5672/airflow
    result_backend = db+postgresql://airflow:airflow@postgres:5432/airflow
    worker_concurrency = 8
    
    [webserver]
    base_url = http://localhost:32080
    web_server_port = 8080
    default_ui_timezone = UTC
    
    [scheduler]
    catchup_by_default = False
---
# Déploiement PostgreSQL
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: airflow
  labels:
    app: airflow
    tier: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: airflow
      tier: database
  template:
    metadata:
      labels:
        app: airflow
        tier: database
    spec:
      containers:
        - name: postgres
          image: postgres:15
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_USER
              value: "airflow"
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: airflow-secrets
                  key: postgres-password
            - name: POSTGRES_DB
              value: "airflow"
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
          volumeMounts:
            - name: postgres-data
              mountPath: /var/lib/postgresql/data
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "1Gi"
              cpu: "500m"
          livenessProbe:
            exec:
              command:
                - sh
                - -c
                - exec pg_isready -h 127.0.0.1 -U airflow
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            exec:
              command:
                - sh
                - -c
                - exec pg_isready -h 127.0.0.1 -U airflow
            initialDelaySeconds: 5
            periodSeconds: 5
      volumes:
        - name: postgres-data
          persistentVolumeClaim:
            claimName: postgres-pvc
---
# PVC pour PostgreSQL
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: airflow
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
# Déploiement RabbitMQ
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rabbitmq
  namespace: airflow
  labels:
    app: airflow
    tier: message-broker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: airflow
      tier: message-broker
  template:
    metadata:
      labels:
        app: airflow
        tier: message-broker
    spec:
      containers:
        - name: rabbitmq
          image: rabbitmq:3-management
          ports:
            - containerPort: 5672
              name: amqp
            - containerPort: 15672
              name: management
          env:
            - name: RABBITMQ_DEFAULT_USER
              value: "airflow"
            - name: RABBITMQ_DEFAULT_PASS
              valueFrom:
                secretKeyRef:
                  name: airflow-secrets
                  key: rabbitmq-password
            - name: RABBITMQ_DEFAULT_VHOST
              value: "/airflow"
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "300m"
          livenessProbe:
            exec:
              command:
                - rabbitmq-diagnostics
                - status
            initialDelaySeconds: 60
            periodSeconds: 30
          readinessProbe:
            exec:
              command:
                - rabbitmq-diagnostics
                - ping
            initialDelaySeconds: 20
            periodSeconds: 10
---
# Job d'initialisation de la base de données
apiVersion: batch/v1
kind: Job
metadata:
  name: airflow-db-init
  namespace: airflow
spec:
  template:
    metadata:
      labels:
        app: airflow
        job: db-init
    spec:
      restartPolicy: OnFailure
      containers:
        - name: init
          image: apache/airflow:2.8.1
          command: ["bash", "-c"]
          args:
            - |
              set -e
              echo "Waiting for PostgreSQL..."
              until pg_isready -h postgres -p 5432 -U airflow; do
                sleep 2
              done
              echo "Initializing Airflow database..."
              airflow db migrate
              echo "Creating admin user..."
              airflow users create \
                --username admin \
                --firstname Admin \
                --lastname User \
                --role Admin \
                --email admin@example.com \
                --password admin
              echo "Initialization completed successfully!"
          env:
            - name: AIRFLOW__CORE__EXECUTOR
              value: "CeleryExecutor"
            - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
              value: "postgresql+psycopg2://airflow:airflow@postgres:5432/airflow"
            - name: AIRFLOW__CELERY__BROKER_URL
              value: "amqp://airflow:airflow@rabbitmq:5672/airflow"
            - name: AIRFLOW__CORE__LOAD_EXAMPLES
              value: "False"
            - name: AIRFLOW__CORE__FERNET_KEY
              valueFrom:
                secretKeyRef:
                  name: airflow-secrets
                  key: fernet-key
            - name: PGUSER
              value: "airflow"
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: airflow-secrets
                  key: postgres-password"
            - name: PGHOST
              value: "postgres"
            - name: PGPORT
              value: "5432"
            - name: PGDATABASE
              value: "airflow"
---
# Déploiement Airflow Webserver
apiVersion: apps/v1
kind: Deployment
metadata:
  name: airflow-webserver
  namespace: airflow
  labels:
    app: airflow
    tier: webserver
spec:
  replicas: 1
  selector:
    matchLabels:
      app: airflow
      tier: webserver
  template:
    metadata:
      labels:
        app: airflow
        tier: webserver
    spec:
      initContainers:
        - name: wait-for-db
          image: postgres:15
          command: ['sh', '-c', 'until pg_isready -h postgres -p 5432 -U airflow; do echo waiting for database; sleep 2; done;']
          env:
            - name: PGUSER
              value: "airflow"
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: airflow-secrets
                  key: postgres-password
      containers:
        - name: webserver
          image: apache/airflow:2.8.1
          command: ["airflow", "webserver"]
          ports:
            - containerPort: 8080
          env:
            - name: AIRFLOW__CORE__EXECUTOR
              value: "CeleryExecutor"
            - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
              value: "postgresql+psycopg2://airflow:airflow@postgres:5432/airflow"
            - name: AIRFLOW__CELERY__BROKER_URL
              value: "amqp://airflow:airflow@rabbitmq:5672/airflow"
            - name: AIRFLOW__CELERY__RESULT_BACKEND
              value: "db+postgresql://airflow:airflow@postgres:5432/airflow"
            - name: AIRFLOW__CORE__LOAD_EXAMPLES
              value: "False"
            - name: AIRFLOW__CORE__FERNET_KEY
              valueFrom:
                secretKeyRef:
                  name: airflow-secrets
                  key: fernet-key
            - name: AIRFLOW__WEBSERVER__EXPOSE_CONFIG
              value: "True"
          resources:
            requests:
              memory: "512Mi"
              cpu: "200m"
            limits:
              memory: "1Gi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 60
            periodSeconds: 30
            timeoutSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
---
# Déploiement Airflow Scheduler
apiVersion: apps/v1
kind: Deployment
metadata:
  name: airflow-scheduler
  namespace: airflow
  labels:
    app: airflow
    tier: scheduler
spec:
  replicas: 1
  selector:
    matchLabels:
      app: airflow
      tier: scheduler
  template:
    metadata:
      labels:
        app: airflow
        tier: scheduler
    spec:
      initContainers:
        - name: wait-for-db
          image: postgres:15
          command: ['sh', '-c', 'until pg_isready -h postgres -p 5432 -U airflow; do echo waiting for database; sleep 2; done;']
          env:
            - name: PGUSER
              value: "airflow"
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: airflow-secrets
                  key: postgres-password
      containers:
        - name: scheduler
          image: apache/airflow:2.8.1
          command: ["airflow", "scheduler"]
          env:
            - name: AIRFLOW__CORE__EXECUTOR
              value: "CeleryExecutor"
            - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
              value: "postgresql+psycopg2://airflow:airflow@postgres:5432/airflow"
            - name: AIRFLOW__CELERY__BROKER_URL
              value: "amqp://airflow:airflow@rabbitmq:5672/airflow"
            - name: AIRFLOW__CELERY__RESULT_BACKEND
              value: "db+postgresql://airflow:airflow@postgres:5432/airflow"
            - name: AIRFLOW__CORE__LOAD_EXAMPLES
              value: "False"
            - name: AIRFLOW__CORE__FERNET_KEY
              valueFrom:
                secretKeyRef:
                  name: airflow-secrets
                  key: fernet-key
          resources:
            requests:
              memory: "512Mi"
              cpu: "300m"
            limits:
              memory: "1Gi"
              cpu: "800m"
          livenessProbe:
            exec:
              command:
                - sh
                - -c
                - airflow jobs check --job-type SchedulerJob --hostname $$HOSTNAME
            initialDelaySeconds: 120
            periodSeconds: 60
---
# Déploiement Airflow Worker avec HPA
apiVersion: apps/v1
kind: Deployment
metadata:
  name: airflow-worker
  namespace: airflow
  labels:
    app: airflow
    tier: worker
spec:
  replicas: 2
  selector:
    matchLabels:
      app: airflow
      tier: worker
  template:
    metadata:
      labels:
        app: airflow
        tier: worker
    spec:
      initContainers:
        - name: wait-for-db
          image: postgres:15
          command: ['sh', '-c', 'until pg_isready -h postgres -p 5432 -U airflow; do echo waiting for database; sleep 2; done;']
          env:
            - name: PGUSER
              value: "airflow"
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: airflow-secrets
                  key: postgres-password
      containers:
        - name: worker
          image: apache/airflow:2.8.1
          command: 
            - airflow
            - celery
            - worker
          env:
            - name: AIRFLOW__CORE__EXECUTOR
              value: "CeleryExecutor"
            - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
              value: "postgresql+psycopg2://airflow:airflow@postgres:5432/airflow"
            - name: AIRFLOW__CELERY__BROKER_URL
              value: "amqp://airflow:airflow@rabbitmq:5672/airflow"
            - name: AIRFLOW__CELERY__RESULT_BACKEND
              value: "db+postgresql://airflow:airflow@postgres:5432/airflow"
            - name: AIRFLOW__CORE__LOAD_EXAMPLES
              value: "False"
            - name: AIRFLOW__CORE__FERNET_KEY
              valueFrom:
                secretKeyRef:
                  name: airflow-secrets
                  key: fernet-key
            - name: AIRFLOW__CELERY__WORKER_CONCURRENCY
              value: "8"
          resources:
            requests:
              memory: "512Mi"
              cpu: "300m"
            limits:
              memory: "2Gi"
              cpu: "1000m"
          livenessProbe:
            exec:
              command:
                - sh
                - -c
                - celery -A airflow.executors.celery_executor inspect ping -d celery@$$HOSTNAME
            initialDelaySeconds: 120
            periodSeconds: 60
---
# Déploiement Flower (Monitoring)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: airflow-flower
  namespace: airflow
  labels:
    app: airflow
    tier: flower
spec:
  replicas: 1
  selector:
    matchLabels:
      app: airflow
      tier: flower
  template:
    metadata:
      labels:
        app: airflow
        tier: flower
    spec:
      containers:
        - name: flower
          image: apache/airflow:2.8.1
          command: ["airflow", "celery", "flower"]
          ports:
            - containerPort: 5555
          env:
            - name: AIRFLOW__CORE__EXECUTOR
              value: "CeleryExecutor"
            - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
              value: "postgresql+psycopg2://airflow:airflow@postgres:5432/airflow"
            - name: AIRFLOW__CELERY__BROKER_URL
              value: "amqp://airflow:airflow@rabbitmq:5672/airflow"
            - name: AIRFLOW__CELERY__RESULT_BACKEND
              value: "db+postgresql://airflow:airflow@postgres:5432/airflow"
            - name: AIRFLOW__CORE__FERNET_KEY
              valueFrom:
                secretKeyRef:
                  name: airflow-secrets
                  key: fernet-key
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "300m"
          livenessProbe:
            httpGet:
              path: /
              port: 5555
            initialDelaySeconds: 60
            periodSeconds: 30
---
# Horizontal Pod Autoscaler pour les Workers
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: airflow-worker-hpa
  namespace: airflow
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: airflow-worker
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
      - type: Pods
        value: 2
        periodSeconds: 60
      selectPolicy: Max
---
# HPA pour le Scheduler
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: airflow-scheduler-hpa
  namespace: airflow
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: airflow-scheduler
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
EOF

# 2. Rendre le script exécutable
chmod +x deploy-airflow.sh

# 3. Lancer le déploiement
./deploy-airflow.sh

# 4. Vérifier le statut
kubectl get all -n airflow

# 5. Accéder à Airflow
kubectl port-forward -n airflow service/airflow-webserver 8080:8080
# Puis ouvrir http://localhost:8080