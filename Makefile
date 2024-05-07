.PHONY: argocd

#helm upgrade --install --namespace argocd --create-namespace argocd argocd/argo-cd --set global.image.tag=v2.9.12 --set repoServer.extraArguments[0]="--repo-cache-expiration=1m",repoServer.extraArguments[1]="--default-cache-expiration=1m",repoServer.extraArguments[2]="--repo-server-timeout-seconds=240s"  --wait --timeout 5m && \

fix_dns_upstream:
	kubectl -n kube-system get configmap coredns -o yaml | sed 's,forward . /etc/resolv.conf,forward \. 8.8.8.8,' | kubectl apply -f - && \
	kubectl delete pod -n kube-system -l k8s-app=kube-dns

deinstall:
	k3s-uninstall.sh ; \
	sleep 10 # :)

cluster: deinstall
	curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable=traefik" sh -s - --docker && sleep 30 && \
	sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/config && \
	$(MAKE) fix_dns_upstream


argocd:
	helm repo add argocd https://argoproj.github.io/argo-helm && \
	helm repo update argocd && \
	helm upgrade --install --namespace argocd --create-namespace argocd argocd/argo-cd -f ./argocd_values.yaml --wait --timeout 5m && \
	kubectl apply -f ./kcl-cmp.yaml && \
	kubectl -n argocd patch deploy/argocd-repo-server -p "`cat ./patch-argocd-repo-server.yaml`" && \
	kubectl wait --for=condition=ready pod -n argocd -l app.kubernetes.io/name=argocd-repo-server --timeout=600s

kcl_tini:
	docker build -t metacoma/kcl-tini:latest -f kcl_tini.Dockerfile .

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

#.PHONY: argocd_password
argocd_password:
	$(eval ARGOCD_PASSWORD := $(shell kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}"  |base64 -d;echo))
	echo $(ARGOCD_PASSWORD)

#.PHONY: argocd_login
argocd_login: kubectl_proxy argocd_password
	argocd login --insecure --username admin --password $(ARGOCD_PASSWORD) localhost:8080


.PHONY: argocd_app
argocd_app: argocd
	kubectl apply -f argocd_mindwm_app.yaml

argocd_sync: argocd_app argocd_login
	argocd app sync mindwm-gitops

mindwm_lifecycle: cluster argocd argocd_sync

