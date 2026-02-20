oc describe network.config.openshift.io cluster

oc get network.config.openshift.io cluster -o jsonpath='{.spec.networkType}{"\n"}'

oc get network.config.openshift.io cluster -o yaml | grep networkType

oc get network.config.openshift.io/cluster -o jsonpath='{.metadata.annotations.network\.openshift\.io/network-type-migration}{"\n"}'

watch -n 2 'oc get network.config.openshift.io/cluster -o jsonpath="spec={.spec.networkType}  status={.status.networkType}{\"\n\"}"'

watch -n 2 'oc get mcp; echo "----"; oc get nodes'

watch -n 2 'oc get events -n openshift-network-operator --sort-by=.lastTimestamp | tail -n 20'

watch -n 2 'oc get co network'

oc logs -n openshift-network-operator deploy/network-operator --tail=200

oc logs -n openshift-ovn-kubernetes -l app=ovnkube-node --tail=200 | egrep -i "geneve|6081|mtu|tunnel|error|fail|timeout|no route"

⚠️ OJO: no la quites “para abortar” una migración a medias. Hay casos reportados donde quitarla prematuramente deja el cluster en un estado malo.  

oc annotate network.config cluster network.openshift.io/network-type-migration-

