oc get pods -A -o json | \
jq '[.items[] | select(.spec.containers[].name=="istio-proxy")] | length'

oc get pods -A -o json | \
jq -r '
.items[]
| select(.spec.containers[].name=="istio-proxy")
| .metadata.namespace' \
| sort | uniq -c | sort -nr

oc get pods -A -o json | \
jq -r '
.items[]
| select(.spec.containers[].name=="istio-proxy")
| "\(.metadata.namespace)/\(.metadata.name)"'

