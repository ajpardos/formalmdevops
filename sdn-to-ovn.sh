oc describe network.config.openshift.io cluster

oc get network.config.openshift.io cluster -o jsonpath='{.spec.networkType}{"\n"}'

oc get network.config.openshift.io cluster -o yaml | grep networkType
ejecutar 

oc patch network.config.openshift.io cluster \
  --type=merge \
  -p '{"spec":{"networkType":"OVNKubernetes"}}'