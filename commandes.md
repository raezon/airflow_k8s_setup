kubectl delete all --all --grace-period=0 --force
kubectl create -f airflow.yaml
kubectl patch svc flower -p '{"spec":{"selector":{"app":"flower"}}}'