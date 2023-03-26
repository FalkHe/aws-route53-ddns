#!/usr/bin/env bash
#############
# Simplified script to update AWS R53 record with the current public IP via ipify.org
#
# 1. install aws-cli, curl & dig
# 2. configure your aws cli profile with sufficient access rights
# 3. put everything in .env (see .env.dist)
# 4. run ./aws-route53-update.sh
# 5. be happy
#
# Author: https://github.com/FalkHe
# License: WTFPL
#
# use at your own risk
#############
set -e

## load .env
. .env

AWS_PROFILE="${AWS_PROFILE:-default}"
AWS_R53_ZONE_ID="${AWS_R53_ZONE_ID}"
AWS_R53_HOST_NAME="${AWS_R53_HOST_NAME}"
AWS_R53_NS="${AWS_R53_NS}"

## Check AWS CLI
test -x "$(command -v aws)" || ( echo "Error: aws cli not installed" ; exit 1 )

## Check curl
test -x "$(command -v curl)" || ( echo "Error: curl not installed" ; exit 1)

## Check dig
test -x "$(command -v dig)" || ( echo "Error: dig not installed" ; exit 1)

# initialize
{
    echo "[$(date)] Starting \"$(basename ${BASH_SOURCE[0]})\"" \
    && trap 'error "${LINENO}"' ERR \
    && cd "$(dirname "${BASH_SOURCE[0]}")";
} || exit 1

function getIPv4() {
  echo $(curl -s "https://api.ipify.org?format=text")
}

function getIPv6() {
  echo $(curl -s "https://api64.ipify.org?format=text")
}

function updateRecord() {
    if [[ $# -lt 2 ]]
    then
        echo "[$(date)] Function ${FUNCNAME[0]}: Wrong argument count."
        echo "[$(date)]   Usage: ${FUNCNAME[0]} {A|AAAA} {IP}"
        return 1
    fi

    local ZONE_ID="${AWS_R53_ZONE_ID}"
    local RR_NAME="${AWS_R53_HOST_NAME}"
    local RR_TYPE="${1}"
    local RR_VALUE="${2}"
    local RR_TTL=300

    ## create tmp file
    TMP_FILE=$(mktemp --suffix ".aws-r53-ddns.json")
    trap 'rm "${TMP_FILE}"' RETURN

    ## write resource record update to tmp file
    ## https://docs.aws.amazon.com/cli/latest/reference/route53/change-resource-record-sets.html
    cat << JSON > "${TMP_FILE}"
{
  "Comment": "DDNS Update $(date)",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${RR_NAME}",
        "Type": "${RR_TYPE}",
        "TTL": ${RR_TTL},
        "ResourceRecords": [
          {
            "Value": "${RR_VALUE}"
          }
        ]
      }
    }
  ]
}
JSON

    aws route53 change-resource-record-sets --profile ${AWS_PROFILE} --hosted-zone-id "${ZONE_ID}" --change-batch "file://${TMP_FILE}" || exit 1
}

function error() {
    echo -e "[$(date)] Error in line: ${1}"
}

IPv4="$(getIPv4)"
IPv6="$(getIPv6)"

if [[ "${IPv4}" == "${IPv6}" ]]
then
  IPv6=""
fi

test -z "${AWS_R53_NS}" && NS="" || NS="@${AWS_R53_NS}"

if [ "${IPv4}" ]
then
  ## chk current DNS
  CURRENT_IPv4=$(dig A +short ${AWS_R53_HOST_NAME} ${NS})
  if [ "${CURRENT_IPv4}" != "${IPv4}" ]
  then
    updateRecord "A" "${IPv4}" && echo "[$(date)] Updated IPv4 / A to ${IPv4}"
  else
    echo "[$(date)] IPv4 / A is up to date (${IPv4})"
  fi
fi

if [ "${IPv6}" ]
then
  ## chk current DNS
  CURRENT_IPv6=$(dig A +short ${AWS_R53_HOST_NAME} ${NS})
  if [ "${CURRENT_IPv6}" != "${IPv6}" ]
  then
    updateRecord "A" "${IPv6}" && echo "[$(date)] Updated IPv6 / AAAA to ${IPv6}"
  else
    echo "[$(date)] IPv6 / AAAA is up to date (${IPv6})"
  fi
fi
