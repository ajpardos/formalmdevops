#!/bin/bash

# Configuración
TAGS_PROHIBIDOS="dev|uat|qa|master"
TAGS_A_MANTENER=2

echo "========================================================="
echo " ANALIZANDO IMAGESTREAMTAGS (Excluyendo: $TAGS_PROHIBIDOS)"
echo "========================================================="

# 1. Fase de conteo y listado
TOTAL_A_ELIMINAR=0
IMAGE_STREAMS=$(oc get is -o name)

for IS_PATH in $IMAGE_STREAMS; do
    IS_NAME=$(echo $IS_PATH | cut -d'/' -f2)
    
    # Obtener tags filtrando los prohibidos y ordenando por fecha (más reciente arriba)
    # El formato del jsonpath extrae el tag y su fecha de creación para poder ordenar correctamente
    TODOS_LOS_TAGS=$(oc get is $IS_NAME -o jsonpath='{range .status.tags[*]}{.tag}{"\t"}{.items[0].created}{"\n"}{end}' | grep -vE "($TAGS_PROHIBIDOS)" | sort -r -k2 | cut -f1)
    
    COUNT=$(echo "$TODOS_LOS_TAGS" | wc -w)
    
    if [ "$COUNT" -gt "$TAGS_A_MANTENER" ]; then
        A_BORRAR_ESTE_IS=$(echo "$TODOS_LOS_TAGS" | tail -n +$((TAGS_A_MANTENER + 1)))
        NUM_BORRAR=$(echo "$A_BORRAR_ESTE_IS" | wc -w)
        
        echo "IS: $IS_NAME | Tags totales (filtrados): $COUNT | Se borrarán: $NUM_BORRAR"
        for T in $A_BORRAR_ESTE_IS; do
            echo "  -> Candidato: $IS_NAME:$T"
            ((TOTAL_A_ELIMINAR++))
        done
    else
        echo "IS: $IS_NAME | Tags totales (filtrados): $COUNT | No requiere limpieza."
    fi
done

echo ""
echo "========================================================="
echo " RESUMEN:"
echo " Total de tags obsoletos encontrados: $TOTAL_A_ELIMINAR"
echo "========================================================="

# 2. Ejecución (Opcional)
if [ "$TOTAL_A_ELIMINAR" -gt 0 ]; then
    read -p "¿Deseas proceder con la eliminación de estos $TOTAL_A_ELIMINAR tags? (s/n): " CONFIRM
    if [ "$CONFIRM" == "s" ]; then
        for IS_PATH in $IMAGE_STREAMS; do
            IS_NAME=$(echo $IS_PATH | cut -d'/' -f2)
            TODOS_LOS_TAGS=$(oc get is $IS_NAME -o jsonpath='{range .status.tags[*]}{.tag}{"\t"}{.items[0].created}{"\n"}{end}' | grep -vE "($TAGS_PROHIBIDOS)" | sort -r -k2 | cut -f1)
            
            A_BORRAR=$(echo "$TODOS_LOS_TAGS" | tail -n +$((TAGS_A_MANTENER + 1)))
            
            for TAG in $A_BORRAR; do
                if [ ! -z "$TAG" ]; then
                    echo "Eliminando $IS_NAME:$TAG..."
                    oc delete istag "$IS_NAME:$TAG"
                fi
            done
        done
        echo "Limpieza completada."
    else
        echo "Operación cancelada."
    fi
fi