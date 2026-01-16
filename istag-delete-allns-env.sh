#!/bin/bash

# --- Configuración ---
PATTERN="-c-dev-"
TAGS_PROHIBIDOS="dev|uat|qa|master"
TAGS_A_MANTENER=2

echo "================================================================="
echo " BUSCANDO NAMESPACES CON EL PATRÓN: $PATTERN"
echo "================================================================="

# Obtener la lista de namespaces que coinciden con el patrón
NAMESPACES=$(oc get projects -o name | cut -d'/' -f2 | grep "$PATTERN")

if [ -z "$NAMESPACES" ]; then
    echo "No se encontraron namespaces con el patrón $PATTERN"
    exit 0
fi

TOTAL_GENERAL_A_BORRAR=0

# --- Fase 1: Análisis y Listado ---
for NS in $NAMESPACES; do
    echo -e "\nAnalizando Namespace: \e[1;34m$NS\e[0m"
    
    # Obtener los ImageStreams de este namespace
    IMAGE_STREAMS=$(oc get is -n "$NS" -o name)
    
    for IS_PATH in $IMAGE_STREAMS; do
        IS_NAME=$(echo "$IS_PATH" | cut -d'/' -f2)
        
        # Obtener tags filtrados y ordenados por fecha
        TODOS_LOS_TAGS=$(oc get is "$IS_NAME" -n "$NS" -o jsonpath='{range .status.tags[*]}{.tag}{"\t"}{.items[0].created}{"\n"}{end}' 2>/dev/null | grep -vE "($TAGS_PROHIBIDOS)" | sort -r -k2 | cut -f1)
        
        COUNT=$(echo "$TODOS_LOS_TAGS" | wc -w)
        
        if [ "$COUNT" -gt "$TAGS_A_MANTENER" ]; then
            # Seleccionar a partir del tercero más nuevo
            A_BORRAR_ESTE_IS=$(echo "$TODOS_LOS_TAGS" | tail -n +$((TAGS_A_MANTENER + 1)))
            NUM_BORRAR=$(echo "$A_BORRAR_ESTE_IS" | wc -w)
            
            echo "  [IS: $IS_NAME] Tags filtrados: $COUNT | Se borrarán: $NUM_BORRAR"
            for T in $A_BORRAR_ESTE_IS; do
                echo "    -> Candidato: $IS_NAME:$T"
                ((TOTAL_GENERAL_A_BORRAR++))
            done
        fi
    done
done

echo -e "\n================================================================="
echo " RESUMEN TOTAL:"
echo " Total de ImageStreamTags obsoletos en todos los namespaces: $TOTAL_GENERAL_A_BORRAR"
echo "================================================================="

# --- Fase 2: Ejecución ---
if [ "$TOTAL_GENERAL_A_BORRAR" -gt 0 ]; then
    read -p "¿Deseas ejecutar el borrado real en todos estos namespaces? (s/n): " CONFIRM
    if [ "$CONFIRM" == "s" ]; then
        for NS in $NAMESPACES; do
            echo "Limpiando en $NS..."
            IMAGE_STREAMS=$(oc get is -n "$NS" -o name)
            
            for IS_PATH in $IMAGE_STREAMS; do
                IS_NAME=$(echo "$IS_PATH" | cut -d'/' -f2)
                TODOS_LOS_TAGS=$(oc get is "$IS_NAME" -n "$NS" -o jsonpath='{range .status.tags[*]}{.tag}{"\t"}{.items[0].created}{"\n"}{end}' 2>/dev/null | grep -vE "($TAGS_PROHIBIDOS)" | sort -r -k2 | cut -f1)
                
                A_BORRAR=$(echo "$TODOS_LOS_TAGS" | tail -n +$((TAGS_A_MANTENER + 1)))
                
                for TAG in $A_BORRAR; do
                    if [ ! -z "$TAG" ]; then
                        echo "Borrado real: oc delete istag $IS_NAME:$TAG -n $NS"
                        oc delete istag "$IS_NAME:$TAG" -n "$NS"
                    fi
                done
            done
        done
        echo "Limpieza global finalizada."
    else
        echo "Operación cancelada. No se borró nada."
    fi
else
    echo "Nada que limpiar."
fi
