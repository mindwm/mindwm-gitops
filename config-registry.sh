cluster_ip=$(kubectl -n zot get svc zot-int -o jsonpath='{.spec.clusterIP}')

kubectl patch configmap/config-deployment \
	 --namespace knative-serving \
	  --type merge \
	   --patch '{"data":{"registries-skipping-tag-resolving":"'${cluster_ip}'":5000"}}'

kubectl rollout restart deployment.apps/controller -n knative-serving
