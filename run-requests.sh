#!/bin/bash

# --- Дефолтные значения ---
DEFAULT_ADDR="192.168.49.2:31962"
debug=false
variant=""
addr=""  # будет пустым, если не задан

# --- Обработка аргументов ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--debug)
            debug=true
            shift
            ;;
        -a|--addr)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo "Ошибка: --addr требует значения в формате IP:PORT"
                exit 1
            fi
            addr="$2"
            shift 2
            ;;
        -a=*|--addr=*)
            addr="${1#*=}"  # извлекаем значение после =
            shift
            ;;
        *)
            # Позиционный аргумент (variant)
            if [ -z "$variant" ]; then
                variant="$1"
            else
                echo "Ошибка: неожиданный аргумент '$1'"
                echo "Использование: $0 [-d|--debug] [-a|--addr IP:PORT] <variant>"
                exit 1
            fi
            shift
            ;;
    esac
done

# Проверка обязательного аргумента
if [ -z "$variant" ] || [[ ! "$variant" =~ ^(01|02|03|04)$ ]]; then
    echo "Использование: $0 [-d|--debug] [-a|--addr IP:PORT] <номер варианта (01|02|03|04)>"
    exit 1
fi

# --- Определяем финальный адрес: флаг > env > дефолт ---
target_addr="${addr:-${ADDR:-$DEFAULT_ADDR}}"

# --- Формируем host и url ---
host="myapp.${variant}.local"
url="http://${target_addr}/"

# --- Отладочная информация ---
debug_log() {
    [ "$debug" = true ] && echo "[DEBUG] $*" >&2
}

debug_log "Запуск: variant=$variant, host=$host, url=$url"
debug_log "Источник адреса: $([ -n "$addr" ] && echo 'флаг -a' || ([ -n "$ADDR" ] && echo 'env ADDR' || echo 'дефолт'))"

v1=0; v2=0; v3=0; err=0

while true; do
    for i in {1..50}; do
        headers=(-H "Host: $host")
        
        if [ $((RANDOM % 2)) -eq 0 ]; then
            headers+=(-H "x-role: beta_tester")
        fi
        
        response=$(curl -s "${headers[@]}" "$url")
        version=$(echo "$response" | jq -r '.version')
        
        # Подробный лог только в дебаге
        debug_log "[$i] curl -s ${headers[@]} $url"
        debug_log "     → version: $version"
        
        case "$version" in
            "v1") ((v1++)) ;;
            "v2") ((v2++)) ;;
            "v3") ((v3++)) ;;
            *) ((err++)) ;;
        esac
    done

    echo "---- batch done ----"
    echo "$(date +"%Y-%m-%d %H:%M:%S") v1=$v1 v2=$v2 v3=$v3 err=$err"
    
    if [ "$debug" = true ]; then
        total=$((v1 + v2 + v3 + err))
        [ $total -gt 0 ] && echo "[DEBUG] v1=$((100*v1/total))% v2=$((100*v2/total))% v3=$((100*v3/total))% err=$((100*err/total))%"
    fi
    
    sleep 2
    v1=0; v2=0; v3=0; err=0
done