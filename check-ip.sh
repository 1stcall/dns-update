#!/usr/bin/env bash

set -e

IP4_ADD_CURRENT=$(curl -4 icanhazip.com 2>/dev/null)
IP6_ADD_CURRENT=$(curl -6 icanhazip.com 2>/dev/null)
IP4_ADD_DNS=$(dig @ns1.1stcall.uk +short rpicm4-1.1stcall.uk A)
IP6_ADD_DNS=$(dig @ns1.1stcall.uk +short rpicm4-1.1stcall.uk AAAA)

printf "Current adresses are IP4 %s and IP6 %s\n" $IP4_ADD_CURRENT $IP6_ADD_CURRENT
printf "DNS reports adresses are IP4 %s and IP6 %s\n" $IP4_ADD_DNS $IP6_ADD_DNS

if [ $IP4_ADD_CURRENT != $IP4_ADD_DNS ]; then
    TOKEN=$(curl https://ns1.1stcall.uk/api/user/login?user=carl\&pass=Manager09\&includeInfo=false 2>/dev/null | jq -r '.token')
    responce=$(curl https://ns1.1stcall.uk/api/zones/records/update?token=${TOKEN}\&domain=rpicm4-1.1stcall.uk\&zone=1stcall.uk\&type=A\&value=$IP4_ADD_DNS\&newValue=$IP4_ADD_CURRENT\&ptr=false 2>/dev/null)
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
    TOKEN=${TOKEN:-$(curl https://ns1.1stcall.uk/api/user/login?user=carl\&pass=Manager09\&includeInfo=false 2>/dev/null | jq -r '.token')}
    responce=$(curl https://ns1.1stcall.uk/api/zones/records/update?token=${TOKEN}\&domain=rpicm4-1.1stcall.uk\&zone=1stcall.uk\&type=AAAA\&value=$IP6_ADD_DNS\&newValue=$IP6_ADD_CURRENT\&ptr=true 2>/dev/null)
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

if [ ${TOKEN:-unset} != unset ]; then
    responce=$(curl https://ns1.1stcall.uk/api/user/logout?token=$TOKEN 2>/dev/null)
    status=$(echo $responce | jq -r '.status')
    if [ $status == ok ]; then
        printf "Logout successfull\n"
    else
        printf "Logout failed!\n"
        echo $responce | jq
        exit 1
    fi
fi

exit 0
