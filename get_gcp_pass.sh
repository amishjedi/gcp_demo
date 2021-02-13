#!/bin/bash
#
# Authenticates using Azure access token and gets value of a specified variable
#

# URL and ACCOUNT are taken from build vars in library
export CONJUR_APPLIANCE_URL=https://conjur.eastus.cloudapp.azure.com
export CONJUR_ACCOUNT=dev

################  MAIN   ################
# Takes 2 arguments:
#   $1 - host/<dap-host-identity-from-policy>
#   $2 - name of variable to value to return
#
main() {
  if [[ $# -ne 2 ]] ; then
    printf "\nUsage: %s <host-identity> <variable-name>\n" $0
    exit -1
  fi
  local CONJUR_AUTHN_LOGIN=$1
  local variable_name=$2
				# authenticate, get ACCESS_TOKEN
  ACCESS_TOKEN=$(authn_host $CONJUR_AUTHN_LOGIN)
  #echo $ACCESS_TOKEN
  if [[ "$ACCESS_TOKEN" == "" ]]; then
    echo "Authentication failed..."
    exit -1
  fi

 local encoded_var_name=$(urlify "$variable_name")
 curl -s -k -H "Content-Type: application/json" -H "Authorization: Token token=\"$ACCESS_TOKEN\"" $CONJUR_APPLIANCE_URL/secrets/$CONJUR_ACCOUNT/variable/$encoded_var_name
 echo ""
}

##################
# AUTHN HOST
#  $1 - host identity
#
authn_host() {
  local host_id=$1; shift
  
  # get GCP access token for managed identity from instance metadata service (imds)
  imds_endpoint='http://metadata/computeMetadata/v1/instance/service-accounts/default/identity'
  gcp_access_token=$(curl -s -G -H "Metadata-Flavor: Google" --data-urlencode "audience=conjur/dev/${host_id}" --data-urlencode "format=full" "$imds_endpoint")
  
#  echo $gcp_access_token

  if [[ $gcp_access_token == null ]]; then
    echo "Error retrieving GCP access token"
#  else
#    echo "GCP token: $gcp_access_token"
  fi

  authn_gcp_response=$(curl -s \
	  -k \
	  --request POST "$CONJUR_APPLIANCE_URL/authn-gcp/$CONJUR_ACCOUNT/authenticate" \
	  -H 'Content-Type: application/x-www-form-urlencoded' \
	  --data-urlencode jwt=$gcp_access_token)
 # echo "$auth_gcp_response"
  conjur_access_token=$(echo -n $authn_gcp_response| base64 | tr -d '\r\n')
  echo "$conjur_access_token"
}

################
# URLIFY - url encodes input string
# in: $1 - string to encode
# out: encoded string
function urlify() {
        local str=$1; shift
        str=$(echo $str | sed 's= =%20=g')
        str=$(echo $str | sed 's=/=%2F=g')
        str=$(echo $str | sed 's=:=%3A=g')
        str=$(echo $str | sed 's=+=%2B=g')
        str=$(echo $str | sed 's=&=%26=g')
        str=$(echo $str | sed 's=@=%40=g')
        echo $str
}

main "$@"
