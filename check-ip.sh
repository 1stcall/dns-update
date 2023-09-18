#!/usr/bin/env bash

set -euf
set -o pipefail

declare DRYRUN

declare IP_LOOKUP_ADD
declare DNS_LOOKUP_SERVER
declare DNS_API_PROTOCOL
declare DNS_API_SERVER
declare DNS_API_TOKEN
declare DNS_API_PORT
declare DOMAIN
declare HOST
declare USE_TAILSCALE

declare IP4_ADD_CURRENT
declare IP6_ADD_CURRENT
declare IP4_ADD_DNS
declare IP6_ADD_DNS

[ -f .env ] && source .env

DRYRUN=${DRYRUN:-false}
IP_LOOKUP_ADD=${IP_LOOKUP_ADD:-icanhazip.com}
DNS_LOOKUP_SERVER=${DNS_LOOKUP_SERVER:-localhost}
DNS_API_PROTOCOL=${DNS_API_PROTOCOL:-http}
DNS_API_SERVER=${DNS_API_SERVER:-localhost}
DNS_API_PORT=${DNS_API_PORT:-80}
DOMAIN=${DOMAIN:-$(hostname -d)}
HOST=${HOST:-$(hostname -s)}
USE_TAILSCALE=${USE_TAILSCALE:-false}
DNS_API_TOKEN=${DNS_API_TOKEN:-unset}

if [ $USE_TAILSCALE == true ]; then
    IP4_ADD_CURRENT=$(tailscale ip -4)
    IP6_ADD_CURRENT=$(tailscale ip -6)
else
    IP4_ADD_CURRENT=$(curl -4 ${IP_LOOKUP_ADD} 2>/dev/null)
    IP6_ADD_CURRENT=$(curl -6 ${IP_LOOKUP_ADD} 2>/dev/null)
fi

#set -x    
IP4_ADD_DNS=$(dig @${DNS_LOOKUP_SERVER} +short ${HOST}.${DOMAIN} A 2>/dev/null || true)
IP6_ADD_DNS=$(dig @${DNS_LOOKUP_SERVER} +short ${HOST}.${DOMAIN} AAAA 2>/dev/null || true)
#set +x
IP4_ADD_DNS=${IP4_ADD_DNS:-unset}   
IP6_ADD_DNS=${IP6_ADD_DNS:-unset}

printf "DNS Lookup Server is \'%s\'\n" $DNS_LOOKUP_SERVER
printf "DNS API Token is \'%s\'\n" $DNS_API_TOKEN
printf "DNS API protocol is \'%s\'\n" $DNS_API_PROTOCOL
printf "DNS API server is \'%s\'\n" $DNS_API_SERVER
printf "DNS API Port is \'%s\'\n" $DNS_API_PORT
printf "Use Tailscale address is \'%s\'\n" $USE_TAILSCALE
printf "IP lookup address is \'%s\'\n" $IP_LOOKUP_ADD
printf "Domain to check is \'%s\'\n" $DOMAIN
printf "Hostname to update is \'%s\'\n" $HOST
printf "Current adresses are IP4 %s and IP6 %s\n" $IP4_ADD_CURRENT $IP6_ADD_CURRENT
printf "DNS reports adresses are IP4 %s and IP6 %s\n" $IP4_ADD_DNS $IP6_ADD_DNS

[ $DRYRUN == true ] && echo "Exiting due to dryrun." && exit 0
[ ${DNS_API_TOKEN:-unset} = unset ] && echo "DNS_API_TOKEN unset!" && exit 1

if [ $IP4_ADD_CURRENT != $IP4_ADD_DNS ]; then
    if [ $IP4_ADD_DNS != unset ]; then
        responce=$(curl ${DNS_API_PROTOCOL}://${DNS_API_SERVER}:${DNS_API_PORT}/api/zones/records/update?TOKEN=${DNS_API_TOKEN}\&domain=${HOST}.${DOMAIN}\&zone=${DOMAIN}\&type=A\&value=$IP4_ADD_DNS\&newValue=$IP4_ADD_CURRENT\&ptr=true\&createPtrZone=true 2>/dev/null || true)
        status=$(echo $responce | jq -r '.status')
        if [ ${status:-error} == "ok" ]; then
            printf "%s -> %s Updated.\n" $IP4_ADD_DNS $IP4_ADD_CURRENT
        else
            printf "%s\n\n" "DNS update A failed.  Responce follows"
            echo $responce | jq
            exit 1
        fi
    else
        responce=$(curl ${DNS_API_PROTOCOL}://${DNS_API_SERVER}:${DNS_API_PORT}/api/zones/records/add?TOKEN=${DNS_API_TOKEN}\&domain=${HOST}.${DOMAIN}\&zone=${DOMAIN}\&type=A\&ipAddress=${IP4_ADD_CURRENT}\&ptr=true\&createPtrZone=true 2>/dev/null || true)
        status=$(echo $responce | jq -r '.status')

        if [ ${status:-failed} == "ok" ]; then
            printf "%s -> %s Added.\n" $IP4_ADD_DNS $IP4_ADD_CURRENT
        else
            printf "%s\n\n" "DNS add A failed.  Responce follows"
            echo $responce | jq
            exit 1
        fi
    fi
else
    printf "%s Not updated.\n" $IP4_ADD_CURRENT 
fi

if [ $IP6_ADD_CURRENT != $IP6_ADD_DNS ]; then
    if [ $IP6_ADD_DNS != unset ]; then
        responce=$(curl ${DNS_API_PROTOCOL}://${DNS_API_SERVER}:${DNS_API_PORT}/api/zones/records/update?TOKEN=${DNS_API_TOKEN}\&domain=${HOST}.${DOMAIN}\&zone=${DOMAIN}\&type=AAAA\&value=$IP6_ADD_DNS\&newValue=$IP6_ADD_CURRENT\&ptr=true\&createPtrZone=true 2>/dev/null || true)
        status=$(echo $responce | jq -r '.status')

        if [ ${status:-failed} == "ok" ]; then
            printf "%s -> %s Updated.\n" $IP6_ADD_DNS $IP6_ADD_CURRENT
        else
            printf "%s\n\n" "DNS update AAAA failed.  Responce follows"
            echo $responce | jq
            exit 1
        fi
    else
        responce=$(curl ${DNS_API_PROTOCOL}://${DNS_API_SERVER}:${DNS_API_PORT}/api/zones/records/add?TOKEN=${DNS_API_TOKEN}\&domain=${HOST}.${DOMAIN}\&zone=${DOMAIN}\&type=AAAA\&ipAddress=${IP6_ADD_CURRENT}\&ptr=true\&createPtrZone=true 2>/dev/null || true)
        status=$(echo $responce | jq -r '.status')

        if [ ${status:-failed} == "ok" ]; then
            printf "%s -> %s Added.\n" $IP6_ADD_DNS $IP6_ADD_CURRENT
        else
            printf "%s\n\n" "DNS add AAAA failed.  Responce follows"
            echo $responce | jq
            exit 1
        fi
    fi
else
    printf "%s Not updated.\n" $IP6_ADD_CURRENT 
fi

exit 0
