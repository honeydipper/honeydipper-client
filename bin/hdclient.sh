#!/bin/bash


#######################################################
# 
# Copyright 2019 Honey Science Corporation
# 
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, you can obtain one at http://mozilla.org/MPL/2.0/.
# 
#######################################################


#######################################################
# 
# This script includes some functions that can be used
# for interacting with Honeydipper through webhook or
# APIs. It can be used interactively or as a dependency
# to another script.
#
# The best way to make the functions available is to
# source in this file from your shell's rc file.
#
# To easily configure the access to your Honeydipper
# daemon, place a file named honeydipper in your home
# directory under .config, should include following
# environment variables
# 
# HD_WEBHOOK_URLPREFIX="< webhook prefix e.g. https://dipper-webhook.myhoneydipper.com >"
# HD_API_URLPREFIX="< api prefix e.g. https://dipper-api.myhoneydipper.com >"
# HD_API_TOKEN="< api token >"
# HD_WEBHOOK_TOKEN="< webhook token >"
#
# Alternatively, you can use HD_USER_NAME and HD_USER_PASS
# instead of HD_API_TOKEN.
#
# examples:
#
# $ hdget events
#
#     this will list all the events currently executing
#     workflows in json format.
#
# $ hdwebhook mywebhook/test
#
#     this will send a webhook request with required
#     such as https://dipper-webhook.myhoneydipper.com/mywebhook/test
#     The eventID will be stored in environment variable
#     HD_EVENT_ID.
#
# $ hdwait
#
#     this will wait for the event $HD_EVENT_ID to finish
#     executing the workflows. check the results with
#     $HD_SESSION_SUCCESS and $HD_SESSION_FAILURE_ERROR
#
#######################################################

function setupHoneydipper() {
  if [[ -z "$SKIP_HONEYDIPPER_CONFIG" ]] && [[ -f ~/.config/honeydipper/env ]]; then
    unset HD_WEBHOOK_URLPREFIX
    unset HD_API_URLPREFIX
    unset HD_API_TOKEN
    unset HD_WEBHOOK_TOKEN
    unset HD_USER_NAME
    unset HD_USER_PASS
    unset HD_USE_GCLOUD_IAP
    unset HD_GCLOUD_IAP_AUDIENCE
    source ~/.config/honeydipper/env
  fi

  if ! [[ -x "$(command -v curl)" ]]; then
    echo curl command not found >&2
    return 1
  fi

  if ! [[ -x "$(command -v jq)" ]]; then
    echo jq command not found >&2
    return 1
  fi
}

function hdget() {
  setupHoneydipper || return 1

  local api="$1"
  local urlprefix="${2-$HD_API_URLPREFIX}"

  if [[ -z "$api" ]]; then
    echo api not specified >&2
    return 1
  fi

  if [[ -z "$urlprefix" ]]; then
    echo api urlprefix not specified >&2
    return 1
  fi

  if [[ -z "$HD_API_TOKEN" ]] && [[ -z "$HD_USER_NAME" ]] && [[ "$HD_USE_GCLOUD_IAP" != "true" ]]; then
    echo HD_API_TOKEN, HD_USER_NAME not specified or HD_USE_GCLOUD_IAP not true >&2
    return 1
  fi

  if [[ -n "$HD_USER_NAME" ]] && [[ -z "$HD_USER_PASS" ]]; then
    echo HD_USER_PASS not specified >&2
    return 1
  fi

  if [[ "$HD_USE_GCLOUD_IAP" == "true" ]] && [[ -z "$HD_GCLOUD_IAP_AUDIENCE" ]]; then
    echo HD_GCLOUD_IAP_AUDIENCE not specified >&2
    return 1
  fi

  if [[ "$HD_USE_GCLOUD_IAP" == "true" ]]; then
    local token="$(getGoogleIAPToken)"
    if [[ "$token" == "null" ]]; then
      echo Unable to get IAP token >&2
      return 1
    fi
    local auth=( "-H" "Authorization: bearer $token" )
  elif [[ -n "$HD_USER_NAME" ]]; then
    local auth=( "-u" "$HD_USER_NAME:$HD_USER_PASS" )
  else
    local auth=( "-H" "Authorization: bearer $HD_API_TOKEN" )
  fi

  # reuse HD_RETURN unless not defined
  if [[ -z "$HD_RETURN" ]]; then
    export HD_RETURN="$(mktemp)"
  fi

  export HD_STATUS_CODE="$(curl -s -o "$HD_RETURN" -w "%{http_code}" "${auth[@]}" "$urlprefix/$api")"
  local ret="$?"

  if [[ -z "$HD_SILENT" ]]; then
    cat "$HD_RETURN"; echo # add a new line
  fi

  return "$ret"
}

function hdwebhook() {
  setupHoneydipper || return 1

  local hook="$1"
  local parameters="$2"
  local urlprefix="${3-$HD_WEBHOOK_URLPREFIX}"

  if [[ -z "$hook" ]]; then
    echo hook not specified >&2
    return 1
  fi

  if [[ -z "$HD_WEBHOOK_TOKEN" ]]; then
    echo webhook urlprefix not specified >&2
    return 1
  fi

  if [[ -z "$HD_WEBHOOK_TOKEN" ]]; then
    echo HD_WEBHOOK_TOKEN not specified >&2
    return 1
  fi

  # reuse HD_WEBHOOK_RETURN unless not defined
  if [[ -z "$HD_WEBHOOK_RETURN" ]]; then
    export HD_WEBHOOK_RETURN="$(mktemp)"
  fi

  export HD_WEBHOOK_STATUS_CODE="$(curl -s -o "$HD_WEBHOOK_RETURN" -w "%{http_code}" -H "Token: $HD_WEBHOOK_TOKEN" "$urlprefix/$hook?accept_uuid&$parameters")"
  local ret="$?"

  if [[ "$HD_WEBHOOK_STATUS_CODE" != "200" ]]; then
    echo got status code "$HD_WEBHOOK_STATUS_CODE" >&2
    return 1
  fi

  export HD_EVENT_ID="$(cat "$HD_WEBHOOK_RETURN" | jq -r ".eventID")"
 
  if [[ -z "$HD_SILENT" ]]; then
    echo "$HD_EVENT_ID"
  fi

  return "$ret"
}

function hdwait() {
  setupHoneydipper || return 1

  local retry=5
  while (( $retry > 0 )); do
    SKIP_HONEYDIPPER_CONFIG=1 HD_SILENT=1 hdget "events/$HD_EVENT_ID/wait" "$@"
    if (( $HD_STATUS_CODE < 300 )) && (( $HD_STATUS_CODE >= 200 )); then
      break
    fi
    sleep 2
    retry="$(( retry - 1 ))"
  done

  if (( $retry == 0 )); then
    if [[ -z "$HD_SILENT" ]]; then
      # display the session results
      cat "$HD_RETURN"; echo # add a new line
    fi
    echo unable to wait for the event >&2
    return 1
  fi

  while [[ "$HD_STATUS_CODE" == "202" ]]; do
    SKIP_HONEYDIPPER_CONFIG=1 HD_SILENT=1 hdget "events/$HD_EVENT_ID/wait" "$@"
  done

  if [[ -z "$HD_SILENT" ]]; then
    # display the session results
    cat "$HD_RETURN"; echo # add a new line
  fi

  if [[ "$HD_STATUS_CODE" != "200" ]]; then
    echo "got status code $HD_STATUS_CODE" >&2
    return 1
  fi

  local JQ_FILTER=".[].sessions | (.[].status, .[].exported.job_status?)"
  local JQ_RESULTS="$(cat "$HD_RETURN" | jq -r "$JQ_FILTER")"

  export HD_SESSION_SUCCESS="$(echo "$JQ_RESULTS" | grep -c 'success')"
  export HD_SESSION_FAILURE_ERROR="$(echo "$JQ_RESULTS" | grep -c 'failure\|error')"
}

function hdwebhook_wait() {
  hdwebhook "$@"
  hdwait
  (( $HD_SESSION_FAILURE_ERROR == 0 ))
}

function hduse() {
  name="$1"
  if [[ -z "$name" ]]; then
    echo please specify an environment >&2
    return 1
  fi

  if [[ ! -f ~/.config/honeydipper/envs/"$name" ]]; then
    echo the environment is not defined, "~/.config/honeydipper/envs/$name" is missing >&2
    return 1
  fi

  cp ~/.config/honeydipper/envs/"$name" ~/.config/honeydipper/env
  echo "$name" > ~/.config/honeydipper/current
}

function hdenv() {
  ls ~/.config/honeydipper/envs/* |
    xargs -L1 basename |
    cut -d'.' -f2 |
    awk '{if ($1 == "'$(<~/.config/honeydipper/current)'") { print "*",$1; } else {print " ",$1; }}'
}

function getFreePort() {
    local used_ports="$( netstat -naf inet|grep '^tcp' | awk '{print $4;}' | awk -F. '{print $NF;}' | grep -v '*' | sort -u )"
    local -i port=3000
    local -i last_port=65000
    while [[ "$port" -le "$last_port" ]]; do
        if echo "$used_ports" | grep -q -w "$port"; then
            port="$(( port + 1 ))"
        else
            echo "$port"
            return
        fi
    done
}

function getGoogleIAPToken() {
    local suffix="${HD_GCLOUD_IAP_AUDIENCE%%.*}"
    local token_file="$HOME/.config/honeydipper/runtime/gcp_token.$suffix"

    if [[ ! -f "$token_file" ]] || [[ -n "$(find "$token_file" -mmin +59)" ]] || ! jq -e '.id_token' "$token_file" > /dev/null; then
        fetchGoogleIAPTokenFile
    elif [[ -n "$(find "$token_file" -mmin +5)" ]]; then
        if ! jq -e '.refresh_token' "$token_file" > /dev/null; then
            fetchGoogleIAPTokenFile
        else
            refreshGoogleIAPTokenFile
        fi
    fi
    if ! jq -e -r ".id_token" "$token_file"; then
        cat "$token_file" >&2
    fi
}

function fetchGoogleIAPTokenFile() {
    local suffix="${HD_GCLOUD_IAP_AUDIENCE%%.*}"
    local token_file="$HOME/.config/honeydipper/runtime/gcp_token.$suffix"
    local client_creds="$HOME/.config/honeydipper/creds/gcp.$suffix"
    local client_id="$(cat "$client_creds" | jq -r ".installed.client_id")"
    local client_secret="$(cat "$client_creds" | jq -r ".installed.client_secret")"

    local io="$(mktemp -u)"
    mkfifo $io

    local port="$( getFreePort )"
    if [[ -z "$port" ]]; then
        echo  "Can't find a free local tcp port." >&2
        return 1
    fi

    (
        cat $io |
        nc -l $port |
        (
            local g url v
            read -r g url v
            local urltail="${url#*code=}"
            local code="${urltail%%\&*}"
            echo -e "HTTP/1.1 302\r\nLocation: https://honeydipper.io\r\n\r" > $io
            curl -s \
                --data client_id="$client_id" \
                --data client_secret="$client_secret" \
                --data code="$code" \
                --data audience="$HD_GCLOUD_IAP_AUDIENCE" \
                --data redirect_uri="http://localhost:$port" \
                --data grant_type=authorization_code \
                https://oauth2.googleapis.com/token
        ) > "$token_file"
    ) &
    pid="$!"
    trap "rm -f $io; pkill -P $pid; kill $pid; exit" 1 2 3 6 15

    open "https://accounts.google.com/o/oauth2/v2/auth?client_id=${client_id}&response_type=code&scope=openid%20email&access_type=offline&redirect_uri=http://localhost:${port}&cred_ref=true"

    wait "$pid"
    rm -f "$io"
}

function refreshGoogleIAPTokenFile() {
    local suffix="${HD_GCLOUD_IAP_AUDIENCE%%.*}"
    local token_file="$HOME/.config/honeydipper/runtime/gcp_token.$suffix"
    local client_creds="$HOME/.config/honeydipper/creds/gcp.$suffix"
    local client_id="$(cat "$client_creds" | jq -r ".installed.client_id")"
    local client_secret="$(cat "$client_creds" | jq -r ".installed.client_secret")"
    local refresh_token="$(jq -r ".refresh_token" "$token_file")"

    curl -s \
        --data client_id="$client_id" \
        --data client_secret="$client_secret" \
        --data refresh_token="$refresh_token" \
        --data audience="$HD_GCLOUD_IAP_AUDIENCE" \
        --data grant_type=refresh_token \
        https://oauth2.googleapis.com/token |
    jq '. += {"refresh_token": "'"$refresh_token"'"}' > "$token_file"
}

function hdwipe() {
    rm -f $HOME/.config/honeydipper/runtime/*
}
