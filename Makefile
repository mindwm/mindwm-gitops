.PHONY: argocd
argocd:
	helm repo add argocd https://argoproj.github.io/argo-helm && \
	helm repo update argocd && \
	helm upgrade --install --namespace argocd --create-namespace argocd argocd/argo-cd --set global.image.tag=v2.9.12 --wait --timeout 5m && \
	kubectl apply -f ./kcl-cmp.yaml && \
	kubectl -n argocd patch deploy/argocd-repo-server -p "`cat ./patch-argocd-repo-server.yaml`" && \
	kubectl wait --for=condition=ready pod -n argocd -l app.kubernetes.io/name=argocd-repo-server --timeout=600s

.PHONY: kubectl_proxy
kubectl_proxy:
	kubectl port-forward service/argocd-server -n argocd 8080:443 &
kcl_plugin_context:
	kubectl -n argocd exec -it `kubectl -n argocd get pod -l app.kubernetes.io/component=repo-server -o name` -c my-plugin -- /bin/bash
kcl_log:
	kubectl -n argocd logs -f `kubectl -n argocd get pod -l app.kubernetes.io/component=repo-server -o name` -c repo-server
my_plugin:
	kubectl -n argocd logs -f `kubectl -n argocd get pod -l app.kubernetes.io/component=repo-server -o name` -c my-plugin
.PHONY: argocd_password
argocd_password:
	$(eval ARGOCD_PASSWORD := $(shell kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}"  |base64 -d;echo))
.PHONY: argocd_login
argocd_login: kubectl_proxy argocd_password
	argocd login --insecure --username admin --password $(ARGOCD_PASSWORD) localhost:8080

.PHONY: argocd_app
argocd_app: argocd_login
	argocd app create mindwm \
		--repo https://github.com/mindwm/mindwm-gitops \
		--path . \
		--dest-namespace default \
		--dest-server https://kubernetes.default.svc \
		--revision master \
		--config-management-plugin kcl-v1.0
.PHONY: argocd_password
argocd_password:
	$(eval ARGOCD_PASSWORD := $(shell kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}"  |base64 -d;echo))
.PHONY: argocd_login
argocd_login: kubectl_proxy argocd_password
	argocd login --insecure --username admin --password $(ARGOCD_PASSWORD) localhost:8080

.PHONY: argocd_app
argocd_app: argocd_login
	argocd app create mindwm \
                --repo https://github.com/mindwm/mindwm-gitops \
                --path . \
                --dest-namespace default \
                --dest-server https://kubernetes.default.svc \
		--revision master \
                --config-management-plugin kcl-v1.0
