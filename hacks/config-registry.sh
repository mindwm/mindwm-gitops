cluster_ip=$(kubectl -n zot get svc zot-int -o jsonpath='{.spec.clusterIP}')

kubectl patch configmap/config-deployment \
	 --namespace knative-serving \
	  --type merge \
	   --patch '{"data":{"registries-skipping-tag-resolving":"'${cluster_ip}':5000,zot-int.zot:5000,zot-int.zot.svc.cluster.local:5000,0.0.0.0:30001"}}'

kubectl rollout restart deployment.apps/controller -n knative-serving

cat /etc/docker/daemon.json | jq '.["insecure-registries"] += ["'${cluster_ip}':5000"]' #> tmp.json && mv tmp.json /etc/docker/daemon.json
