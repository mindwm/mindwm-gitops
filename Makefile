.PHONY: argocd

ARGOCD_HOST_PORT := 38080

TARGET_REVISION := master

KUBECTL_RUN_OPTS := -i --rm -v ~/.kube:/kube -e KUBECONFIG=/kube/config --network=host -v`pwd`:/host -w /host -u root --entrypoint /bin/sh bitnami/kubectl:latest -c
KUBECTL_RUN := docker run $(KUBECTL_RUN_OPTS)
KUBECTL_IT_RUN := docker run -it $(KUBECTL_RUN_OPTS)
HELM_RUN := docker run --rm -v ~/.kube:/root/.kube -e KUBECONFIG=/root/.kube/config --network=host -v`pwd`:/host -w /host --entrypoint /bin/sh alpine/helm:latest -c

MIN_DOCKER_SERVER_VERSION := 1.46
DOMAIN := stg1.mindwm.local

verify_docker_api_server_version:
	docker version -f json | jq -e '.Server.ApiVersion | select(tonumber >= $(MIN_DOCKER_SERVER_VERSION))';

CONTEXT_NAME := pink

#helm upgrade --install --namespace argocd --create-namespace argocd argocd/argo-cd --set global.image.tag=v2.9.12 --set repoServer.extraArguments[0]="--repo-cache-expiration=1m",repoServer.extraArguments[1]="--default-cache-expiration=1m",repoServer.extraArguments[2]="--repo-server-timeout-seconds=240s"  --wait --timeout 5m && \


.ONESHELL: dns_search_domain
dns_search_domain:
	grep -q '^search [^\.]' /etc/resolv.conf || exit 0
	cat<<EOF
	Please turn off search domain option from your resolv.conf file
	More details here:
	https://github.com/mindwm/mindwm-gitops/issues/64
	https://github.com/k3s-io/k3s/issues/5567
	https://github.com/k3s-io/k3s/issues/9286
	EOF
	exit 1 

precheck: verify_docker_api_server_version dns_search_domain

fix_dns_upstream:
	$(KUBECTL_RUN) '\
		while :; do \
			kubectl -n kube-system get pods -l k8s-app=kube-dns | grep coredns || { \
				echo -n .; \
				sleep 1; \
				continue; \
			}; \
			break; \
		done ; \
		kubectl -n kube-system wait --for=condition=Ready pod --timeout=180s -l k8s-app=kube-dns && \
		kubectl -n kube-system get configmap coredns -o yaml | sed "s,forward . /etc/resolv.conf,forward \. 8.8.8.8," | kubectl apply -f - && \
		kubectl delete pod -n kube-system -l k8s-app=kube-dns \
	'


crossplane_rolebinding_workaround:
	$(KUBECTL_RUN) '\
		for i in kcl-function provider-kubernetes provider-helm; do \
			SA=`kubectl -n crossplane-system get sa -o name | grep $$i | sed -e "s|serviceaccount\/|crossplane-system:|g"`; \
			test -n "$$SA" || continue; \
			kubectl get clusterrolebinding $$i-admin-binding || kubectl create clusterrolebinding $$i-admin-binding --clusterrole cluster-admin --serviceaccount=$$SA; \
		done;\
		SA=crossplane-system:crossplane && \
		i=crossplane && \
		kubectl get clusterrolebinding $$i-admin-binding || kubectl create clusterrolebinding $$i-admin-binding --clusterrole cluster-admin --serviceaccount=$$SA &&\
		SA=knative-eventing:jetstream-ch-dispatcher && \
		i=jetstream-ch-dispatcher && \
		kubectl get clusterrolebinding $$i-admin-binding || kubectl create clusterrolebinding $$i-admin-binding --clusterrole cluster-admin --serviceaccount=$$SA \
	    '

deinstall:
	k3s-uninstall.sh ; \
	sleep 10 # :)

cluster: deinstall precheck
	curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable=traefik --cluster-init" sh -s - --docker && sleep 30 && \
	test -d ~/.kube || mkdir ~/.kube ;\
	sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/config && \
	$(MAKE) fix_dns_upstream


argocd:
	$(HELM_RUN) "\
		helm repo add argocd https://argoproj.github.io/argo-helm && \
		helm repo update argocd && \
		helm upgrade --install --namespace argocd --create-namespace argocd argocd/argo-cd -f ./argocd_values.yaml --set server.service.servicePortHttp=$(ARGOCD_HOST_PORT) --wait --timeout 5m \
	"
	$(KUBECTL_RUN) '\
		kubectl apply -f ./kcl-cmp.yaml && \
		kubectl -n argocd patch deploy/argocd-repo-server -p "`cat ./patch-argocd-repo-server.yaml`" && \
		while :; do \
			kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-repo-server --field-selector=status.phase=Running | grep argocd-repo-server || { \
				echo -n .; \
				sleep 1; \
				continue; \
			}; \
			break; \
		done ; \
		kubectl wait --for=condition=ready pod -n argocd -l app.kubernetes.io/name=argocd-repo-server --timeout=600s \
	'

kcl_tini:
	docker build -t metacoma/kcl-tini:latest -f kcl_tini.Dockerfile .

#.PHONY: kubectl_proxy
#kubectl_proxy:
#	pkill -9 -f "^kubectl port-forward service/argocd-server -n argocd 8080:443";\
#	kubectl port-forward service/argocd-server -n argocd 8080:443 &

kcl_plugin_context:
	kubectl -n argocd exec -it `kubectl -n argocd get pod -l app.kubernetes.io/component=repo-server -o name` -c my-plugin -- /bin/bash
kcl_log:
	kubectl -n argocd logs -f `kubectl -n argocd get pod -l app.kubernetes.io/component=repo-server -o name` -c repo-server
my_plugin:
	kubectl -n argocd logs -f `kubectl -n argocd get pod -l app.kubernetes.io/component=repo-server -o name` -c my-plugin

# cd /tmp/sandbox{{ uniq_id }}/
# check Context
# kcl run -D params='{"oxr": {"spec": {"name": "username"^C}' -D params='{"oxr": {"spec": {"name": "contextname"}}}'
function_kcl_exec:
	kubectl -n crossplane-system exec -ti `kubectl -n crossplane-system get pods -l pkg.crossplane.io/function=function-kcl -o name` -- /bin/bash

copy_prog:
	$(eval FUNCTION_KCL_POD := $(shell kubectl -n crossplane-system get pods -l pkg.crossplane.io/function=function-kcl -o name))
	$(eval LAST_FILE := $(shell kubectl -n crossplane-system exec -ti $(FUNCTION_KCL_POD) -- sh -c "ls -ltr /tmp | sed -nr '$$ s,.* (sandbox.*),/tmp/\1/prog.k,p'"))
	kubectl -n crossplane-system exec $(FUNCTION_KCL_POD) -- cat $(LAST_FILE)

stuck_ns:
	kubectl get namespace "$(DELETE_NS)" -o json \
	  | tr -d "\n" | sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/" \
  		| kubectl replace --raw /api/v1/namespaces/$(DELETE_NS)/finalize -f -




#.PHONY: argocd_password
argocd_password:
	$(eval ARGOCD_PASSWORD := $(shell $(KUBECTL_RUN) 'kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}"  |base64 -d;echo'))
	echo $(ARGOCD_PASSWORD)

#.PHONY: argocd_login
argocd_login: argocd_password
	argocd login --insecure --username admin --password $(ARGOCD_PASSWORD) localhost:8080

.PHONY: argocd_app_sync_async
argocd_app_sync_async: argocd_password
	$(KUBECTL_RUN) "\
		kubectl -n argocd exec -ti deployment/argocd-server -- sh -c '\
				argocd login --plaintext --username admin --password $(ARGOCD_PASSWORD) localhost:8080 ;\
				argocd app sync mindwm-gitops --assumeYes --timeout 2100 --async; \
			'\
		"

argocd_app_async_wait: argocd_password
	$(KUBECTL_RUN) "\
		kubectl -n argocd exec -ti deployment/argocd-server -- sh -xc '\
		argocd login --plaintext --username admin --password $(ARGOCD_PASSWORD) localhost:8080 ;\
		for n in 1 2 3 4 5 6; do \
		        argocd app sync mindwm-gitops --assumeYes --timeout 2100 --async || : \
			sleep 1;\
			argocd app wait mindwm-gitops --health --timeout=300 || continue;\
			exit 0;\
		done ; \
		exit 1;\
		';\
	 "

argocd_exec: argocd_password
	@echo kubectl -n argocd exec -ti deployment/argocd-server -- sh -c 'argocd login --plaintext --username admin --password $(ARGOCD_PASSWORD) localhost:8080 && argocd app sync mindwm-gitops'
	$(KUBECTL_IT_RUN) "kubectl -n argocd exec -ti deployment/argocd-server -- bash"


.PHONY: argocd_app
argocd_app: argocd
	 $(KUBECTL_RUN) 'cat argocd_mindwm_app.json | jq ".spec.source.targetRevision = \"$(TARGET_REVISION)\"" | kubectl apply -f -'

argocd_sync: argocd_app argocd_login
	argocd app sync mindwm-gitops

.ONESHELL: mindwm_resources
mindwm_resources:
	export CONTEXT_NAME=$(CONTEXT_NAME)
	export HOST=`hostname -s`
	cat resources/*.yaml | docker run -e CONTEXT_NAME -e USER -e HOST --rm -i bhgedigital/envsubst envsubst | $(KUBECTL_RUN) 'kubectl apply -f -'

#	$(KUBECTL_RUN) 'kubectl apply -f resources/context.yaml'

argocd_apps_ensure: argocd_password
	$(KUBECTL_RUN) "kubectl -n argocd exec -ti deployment/argocd-server -- sh -c 'argocd login --plaintext --username admin --password $(ARGOCD_PASSWORD) localhost:8080 >/dev/null && argocd app list'" | awk '!/^NAME/ {if ($$6 != "Healthy") {print $$0; exit 1}}'

grafana_password:
	$(KUBECTL_RUN) "kubectl -n monitoring get secret -o yaml vm-aio-grafana | yq '.data.admin-password' | base64 -d; echo"

.ONESHELL: service_dashboard
service_dashboard:
	# from https://istio.io/latest/docs/tasks/traffic-management/ingress/ingress-control/
	export INGRESS_NAME=istio-ingressgateway
	export INGRESS_NS=istio-system
	export INGRESS_HOST=$$(kubectl -n "$$INGRESS_NS" get service "$$INGRESS_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
	export INGRESS_PORT=$$(kubectl -n "$$INGRESS_NS" get service "$$INGRESS_NAME" -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
	cat<<EOF
	echo $$INGRESS_HOST argocd.$(DOMAIN) grafana.$(DOMAIN) vm.$(DOMAIN) nats.$(DOMAIN) neo4j.purple.$(DOMAIN) | sudo tee -a /etc/hosts
	http://argocd.$(DOMAIN):$$INGRESS_PORT
	http://grafana.$(DOMAIN):$$INGRESS_PORT
	http://vm.$(DOMAIN):$$INGRESS_PORT
	http://neo4j.purple.$(DOMAIN):$$INGRESS_PORT
	nats://root:r00tpass@nats.$(DOMAIN):4222
	EOF

mindwm_lifecycle: cluster argocd_app argocd_app_sync_async argocd_app_async_wait crossplane_rolebinding_workaround argocd_apps_ensure mindwm_resources service_dashboard

# make mindwm_lifecycle TARGET_REVISION="`git branch ls --show-current`"
