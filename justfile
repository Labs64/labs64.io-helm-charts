# update helm repositories
repo-update:
    helm repo update

# show repositories versions
repo-search:
    helm search repo

# show helm releases
helm-ls:
    helm ls --all-namespaces
