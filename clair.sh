oc -n registry get quayregistry regional -o jsonpath='{.spec.configBundleSecret}'
echo
BUNDLE=$(oc -n registry get quayregistry regional -o jsonpath='{.spec.configBundleSecret}')
echo $BUNDLE

oc -n registry get secret "$BUNDLE" -o jsonpath='{.data}' | tr ',' '\n' | head

for k in $(oc -n registry get secret "$BUNDLE" -o go-template='{{range $k,$v := .data}}{{printf "%s\n" $k}}{{end}}'); do
  echo "== $k =="
  oc -n registry get secret "$BUNDLE" -o jsonpath="{.data.$k}" 2>/dev/null | base64 -d | \
    LC_ALL=C grep -nP '[\x00-\x08\x0B\x0C\x0E-\x1F]' && echo "^^^ CONTROL CHARS EN $k" || echo "OK"
done

oc -n registry get secret | egrep -i 'quay|config|bundle|regional'

for s in $(oc -n registry get secret -o name); do
  oc -n registry get "$s" -o go-template='{{range $k,$v := .data}}{{printf "%s\n" $k}}{{end}}' 2>/dev/null | \
    egrep -q 'config.yaml|config\.yaml|SECRET_KEY|DATABASE_SECRET_KEY' && echo "$s"
done

for s in $(oc -n registry get secret -o name | egrep 'regional-quay-config-secret|regional-quay-registry-managed-secret-keys'); do
  echo "===== $s ====="
  oc -n registry get $s -o yaml | egrep -n 'name:|creationTimestamp:|ownerReferences:|labels:|annotations:'
done

for S in $(oc -n registry get secret -o name | egrep 'regional-quay-config-secret|regional-quay-registry-managed-secret-keys'); do
  echo "### $S ###"
  for k in $(oc -n registry get "$S" -o go-template='{{range $k,$v := .data}}{{printf "%s\n" $k}}{{end}}'); do
    printf "  - %s: " "$k"
    oc -n registry get secret "$S" -o jsonpath="{.data.$k}" 2>/dev/null | base64 -d | \
      LC_ALL=C grep -qP '[\x00-\x08\x0B\x0C\x0E-\x1F]' \
      && echo "CONTROL_CHARS" || echo "OK"
  done
done


