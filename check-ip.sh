#!/usr/bin/env bash

set -euf
set -o pipefail

declare DRYRUN

declare IP4_ADD_CURRENT
declare IP6_ADD_CURRENT
declare IP4_ADD_DNS
declare IP6_ADD_DNS

declare IP_LOOKUP_ADD
declare DNS_PROTOCOL
declare DNS_SERVER
declare DNS_PORT
declare DOMAIN
declare HOST
declare TOKEN
declare USE_TAILSCALE

[ -f .env ] && source .env

DRYRUN=${DRYRUN:-false}
IP_LOOKUP_ADD=${IP_LOOKUP_ADD:-icanhazip.com}
DNS_PROTOCOL=${DNS_PROTOCOL:-http}
DNS_SERVER=${DNS_SERVER:-localhost}
DNS_PORT=${DNS_PORT:-5380}
DOMAIN=${DOMAIN:-$(hostname -d)}
HOST=${HOST:-$(hostname -s)}
USE_TAILSCALE=${USE_TAILSCALE:-false}

if [ $USE_TAILSCALE == true ]; then
    IP4_ADD_CURRENT=$(tailscale ip -4)
    IP6_ADD_CURRENT=$(tailscale ip -6)
else
    IP4_ADD_CURRENT=$(curl -4 ${IP_LOOKUP_ADD} 2>/dev/null)
    IP6_ADD_CURRENT=$(curl -6 ${IP_LOOKUP_ADD} 2>/dev/null)
fi
    
IP4_ADD_DNS=$(dig @${DNS_SERVER} +short ${HOST}.${DOMAIN} A 2>/dev/null || true)
IP6_ADD_DNS=$(dig @${DNS_SERVER} +short ${HOST}.${DOMAIN} AAAA 2>/dev/null || true)
IP4_ADD_DNS=${IP4_ADD_DNS:-unset}   
IP6_ADD_DNS=${IP6_ADD_DNS:-unset}

printf "IP lookup address is \'%s\'\n" $IP_LOOKUP_ADD
printf "DNS API protocol is \'%s\'\n" $DNS_PROTOCOL
printf "DNS API server is \'%s\'\n" $DNS_SERVER
printf "Domain to check is \'%s\'\n" $DOMAIN
printf "Hostname to update is \'%s\'\n" $HOST
printf "Current adresses are IP4 %s and IP6 %s\n" $IP4_ADD_CURRENT $IP6_ADD_CURRENT
printf "DNS reports adresses are IP4 %s and IP6 %s\n" $IP4_ADD_DNS $IP6_ADD_DNS

[ $DRYRUN == true ] && echo "Exiting due to dryrun." && exit 0
[ ${TOKEN:-unset} = unset ] && echo "Token unset!" && exit 1

if [ $IP4_ADD_CURRENT != $IP4_ADD_DNS ]; then
    if [ $IP4_ADD_DNS != unset ]; then
        responce=$(curl ${DNS_PROTOCOL}://${DNS_SERVER}:${DNS_PORT}/api/zones/records/update?token=${TOKEN}\&domain=${HOST}.${DOMAIN}\&zone=${DOMAIN}\&type=A\&value=$IP4_ADD_DNS\&newValue=$IP4_ADD_CURRENT\&ptr=true\&createPtrZone=true 2>/dev/null || true)
        status=$(echo $responce | jq -r '.status')
        if [ ${status:-error} == "ok" ]; then
            printf "%s -> %s Updated.\n" $IP4_ADD_DNS $IP4_ADD_CURRENT
        else
            printf "%s\n\n" "DNS update A failed.  Responce follows"
            echo $responce | jq
            exit 1
        fi
    else
        responce=$(curl ${DNS_PROTOCOL}://${DNS_SERVER}:${DNS_PORT}/api/zones/records/add?token=${TOKEN}\&domain=${HOST}.${DOMAIN}\&zone=${DOMAIN}\&type=A\&ipAddress=${IP4_ADD_CURRENT}\&ptr=true\&createPtrZone=true 2>/dev/null || true)
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
        responce=$(curl ${DNS_PROTOCOL}://${DNS_SERVER}:${DNS_PORT}/api/zones/records/update?token=${TOKEN}\&domain=${HOST}.${DOMAIN}\&zone=${DOMAIN}\&type=AAAA\&value=$IP6_ADD_DNS\&newValue=$IP6_ADD_CURRENT\&ptr=true\&createPtrZone=true 2>/dev/null || true)
        status=$(echo $responce | jq -r '.status')

        if [ ${status:-failed} == "ok" ]; then
            printf "%s -> %s Updated.\n" $IP6_ADD_DNS $IP6_ADD_CURRENT
        else
            printf "%s\n\n" "DNS update AAAA failed.  Responce follows"
            echo $responce | jq
            exit 1
        fi
    else
        responce=$(curl ${DNS_PROTOCOL}://${DNS_SERVER}:${DNS_PORT}/api/zones/records/add?token=${TOKEN}\&domain=${HOST}.${DOMAIN}\&zone=${DOMAIN}\&type=AAAA\&ipAddress=${IP6_ADD_CURRENT}\&ptr=true\&createPtrZone=true 2>/dev/null || true)
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
