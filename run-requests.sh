#!/bin/bash

# commands and examples:
# 01: curl -H "Host: myapp.01.local" -H "x-role: beta_tester"  http://192.168.49.2:31962/  
# 02: curl -H "Host: myapp.02.local" -H "x-role: beta_tester"  http://192.168.49.2:31962/  
# 03: curl -H "Host: myapp.03.local" -H "x-role: beta_tester"  http://192.168.49.2:31962/  
# 04: curl -H "Host: myapp.04.local" -H "x-role: beta_tester"  http://192.168.49.2:31962/  
# 

# Check arguments
if [ $# -ne 1 ]; then
    echo "Использование: $0 <номер варианта (01|02|03|04)>"
    exit 1
fi

variant="$1"
case "$variant" in
    01|02|03|04)
        host="myapp.${variant}.local"
        url="http://192.168.49.2:31962/"
        ;;
    *)
        echo "Неверный аргумент. Допустимые значения: 01, 02, 03, 04"
        exit 1
        ;;
esac

v1=0
v2=0
v3=0
err=0

while true; do
    for i in {1..20}; do

        headers=(-H "Host: $host")
        
        # Adding x-role with 50% chance
        if [ $((RANDOM % 2)) -eq 0 ]; then
            headers+=(-H "x-role: beta_tester")
        fi
        
        # Executing request — IMPORTANT: "${headers[@]}" in quotes!
        response=$(curl -s "${headers[@]}" "$url")
        
        # Extracting version from response
        version=$(echo "$response" | jq -r '.version')
        echo "curl -s ${headers[@]} $url" - version: $version

        # Accounting for version value in variable
        case "$version" in
            "v1") ((v1++)) ;;
            "v2") ((v2++)) ;;
            "v3") ((v3++)) ;;
            *) ((err++)) ;;
        esac
    done

    echo "---- batch done ----"
    echo "v1=$v1 v2=$v2 v3=$v3 err=$err"
    
    sleep 2
    v1=0; v2=0; v3=0; err=0
done
