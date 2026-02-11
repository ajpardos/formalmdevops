#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-egressfirewalls}"
mkdir -p "$OUT_DIR"

# 1) Trae todas las EgressNetworkPolicy (SDN)
ENP_JSON="$(oc get egressnetworkpolicies.network.openshift.io -A -o json)"

# 2) Genera un EgressFirewall por namespace.
#    - Si en un namespace hay varias ENP, concatena todas las reglas en un solo EgressFirewall.
#    - Mantiene el orden original de las reglas dentro de cada ENP.
echo "$ENP_JSON" | jq -r '
  # Lista de namespaces únicos con ENP
  ([.items[].metadata.namespace] | unique)[] as $ns
  |
  {
    apiVersion: "k8s.ovn.org/v1",
    kind: "EgressFirewall",
    metadata: {
      name: "default",
      namespace: $ns
    },
    spec: {
      egress:
        (
          # junta reglas de todas las ENP del namespace (en el orden en que aparezcan)
          [ .items[]
            | select(.metadata.namespace == $ns)
            | .spec.egress[]
          ]
          | map(
              {
                type: .type,
                to: (
                  if (.to.cidrSelector? != null) then { cidrSelector: .to.cidrSelector }
                  elif (.to.dnsName? != null) then { dnsName: .to.dnsName }
                  else {} end
                )
              }
            )
          # quita entradas raras (por si hubiera alguna "to" vacía)
          | map(select((.to|length) > 0))
        )
    }
  }
  | @json
' | while read -r docjson; do
  ns="$(echo "$docjson" | jq -r '.metadata.namespace')"
  echo "$docjson" | jq -r '.' | yq -P > "${OUT_DIR}/${ns}.yaml"
done

echo "Generados EgressFirewall en: ${OUT_DIR}/"
echo "Ejemplo:"
ls -1 "${OUT_DIR}" | head -n 10

chmod +x enp_to_egressfirewall.sh
./enp_to_egressfirewall.sh


oc get egressnetworkpolicies.network.openshift.io -A -o json | jq -r '.items[].metadata.namespace' | sort -u | wc -l

oc get egressnetworkpolicies.network.openshift.io -A -o json | jq -r '
.items[]
| select(any(.spec.egress[]; .to.dnsName? != null))
| .metadata.namespace' | sort -u

for f in egressfirewalls/*.yaml; do
  ns="$(basename "$f" .yaml)"
  last="$(yq -r '.spec.egress[-1].to.cidrSelector + " " + .spec.egress[-1].type' "$f")"
  echo "$ns -> $last"
done | grep -v "0.0.0.0/0 Deny" || true



