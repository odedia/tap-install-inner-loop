helm repo add gitea-charts https://dl.gitea.io/charts/
helm repo update

kubectl create namespace gitea --dry-run=client -oyaml | kubectl apply -f-

ytt -f gitea-helm-values.yaml -f $1 \
  | helm install gitea-charts/gitea --name-template gitea -n gitea -f-

ytt -f gitea-dependencies.yaml -f $1 --ignore-unknown-comments \
  | kubectl apply -f-
