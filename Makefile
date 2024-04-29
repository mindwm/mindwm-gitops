.PHONY: argocd

#helm upgrade --install --namespace argocd --create-namespace argocd argocd/argo-cd --set global.image.tag=v2.9.12 --set repoServer.extraArguments[0]="--repo-cache-expiration=1m",repoServer.extraArguments[1]="--default-cache-expiration=1m",repoServer.extraArguments[2]="--repo-server-timeout-seconds=240s"  --wait --timeout 5m && \

cluster:
	curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable=traefik" sh -s - --docker && sleep 30 && \
	sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/config && \
	kubectl -n kube-system get configmap coredns -o yaml | sed 's,forward . /etc/resolv.conf,forward \. 8.8.8.8,' | kubectl apply -f - && \
	kubectl delete pod -n kube-system -l k8s-app=kube-dns

argocd:
	helm repo add argocd https://argoproj.github.io/argo-helm && \
	helm repo update argocd && \
	helm upgrade --install --namespace argocd --create-namespace argocd argocd/argo-cd -f ./argocd_values.yaml --wait --timeout 5m && \
	kubectl apply -f ./kcl-cmp.yaml && \
	kubectl -n argocd patch deploy/argocd-repo-server -p "`cat ./patch-argocd-repo-server.yaml`" && \
	kubectl wait --for=condition=ready pod -n argocd -l app.kubernetes.io/name=argocd-repo-server --timeout=600s

.PHONY: kubectl_proxy
kubectl_proxy:
	pkill -9 -f "^kubectl port-forward service/argocd-server -n argocd 8080:443";\
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
argocd_app: argocd argocd_login
	argocd app create mindwm \
		--repo https://github.com/mindwm/mindwm-gitops \
		--path . \
		--dest-namespace default \
		--dest-server https://kubernetes.default.svc \
		--revision master \
		--config-management-plugin kcl-v1.0
