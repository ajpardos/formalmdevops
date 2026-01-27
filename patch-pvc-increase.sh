oc patch pvc elasticsearch-elasticsearch-cdm-1-xxxx \
  -n openshift-logging \
  -p '{"spec":{"resources":{"requests":{"storage":"500Gi"}}}}'