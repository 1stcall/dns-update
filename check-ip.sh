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
declare DOMAIN
declare HOST
declare TOKEN

[ -f .env ] && source .env

DRYRUN=${DRYRUN:-false}
IP_LOOKUP_ADD=${IP_LOOKUP_ADD:-icanhazip.com}
DNS_PROTOCOL=${DNS_PROTOCOL:-http}
DNS_SERVER=${DNS_SERVER:-localhost:5380}
DOMAIN=${DOMAIN:-$(hostname -d)}
HOST=${HOST:-$(hostname -s)}

IP4_ADD_CURRENT=$(curl -4 ${IP_LOOKUP_ADD} 2>/dev/null)
IP6_ADD_CURRENT=$(curl -6 ${IP_LOOKUP_ADD} 2>/dev/null)
IP4_ADD_DNS=$(dig @${DNS_SERVER} +short ${HOST}.${DOMAIN} A)
IP6_ADD_DNS=$(dig @${DNS_SERVER} +short ${HOST}.${DOMAIN} AAAA)
IP4_ADD_DNS=${IP4_ADD_DNS:-unset}
IP6_ADD_DNS=${IP6_ADD_DNS:-unset}
printf "DNS IPV6=$IP6_ADD_DNS"
exit 1

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
    responce=$(curl ${DNS_PROTOCOL}://${DNS_SERVER}/api/zones/records/update?token=${TOKEN}\&domain=${HOST}.${DOMAIN}\&zone=${DOMAIN}\&type=A\&value=$IP4_ADD_DNS\&newValue=$IP4_ADD_CURRENT\&ptr=true 2>/dev/null || true)
    status=$(echo $responce | jq -r '.status')

    if [ $status == "ok" ]; then
        printf "%s -> %s Updated.\n" $IP4_ADD_DNS $IP4_ADD_CURRENT
    else
        printf "%s\n\n" "DNS update failed.  Responce follows"
        echo $responce | jq
        exit 1
    fi
else
    printf "%s Not updated.\n" $IP4_ADD_CURRENT 
fi

if [ $IP6_ADD_CURRENT != $IP6_ADD_DNS ]; then
    responce=$(curl ${DNS_PROTOCOL}://${DNS_SERVER}/api/zones/records/update?token=${TOKEN}\&domain=${HOST}.${DOMAIN}\&zone=${DOMAIN}\&type=AAAA\&value=$IP6_ADD_DNS\&newValue=$IP6_ADD_CURRENT\&ptr=true 2>/dev/null || true)
    status=$(echo $responce | jq -r '.status')

    if [ $status == "ok" ]; then
        printf "%s -> %s Updated.\n" $IP6_ADD_DNS $IP6_ADD_CURRENT
    else
        printf "%s\n\n" "DNS update failed.  Responce follows"
        echo $responce | jq
        exit 1
    fi
else
    printf "%s Not updated.\n" $IP6_ADD_CURRENT 
fi

exit 0
