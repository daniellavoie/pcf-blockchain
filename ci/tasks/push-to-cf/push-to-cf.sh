#!/bin/sh

set -x	

CONFIG_FOLDER=config
CF_SPACE_FILE=cf-space/cf-space

if [ -z "$CF_SPACE" ]; then
  if [ ! -z "$CF_SPACE_PREFIX" ]; then
    CF_SPACE="$CF_SPACE_PREFIX-"
  fi
  
  CF_SPACE=$CF_SPACE$(pwgen -s -1)

  echo "Generated a random space named $CF_SPACE."
fi

echo "$CF_SPACE" > CF_SPACE_FILE

createService() {
  if [ ! -z "$DB_NAME" ]; then
    cf create-service $DB_SERVICE_NAME $DB_SERVICE_PLAN $DB_NAME 
  fi
}

cleanSpace() {
  if [ ! -z "$DB_NAME" ]; then
    if [ "true" == "$DB_RECREATE" ]; then
      cf delete-service $DB_NAME -f
    fi
  fi
  
  cf delete -f $APP_NAME
}

exportHost() {
  SPACE_GUID=$(cf curl "/v2/spaces" -X GET -H "Content-Type: application/x-www-form-urlencoded" -d "q=name:${CF_SPACE}" | jq -r '.resources[0].metadata.guid')
  ROUTES_URL=$(cf curl "/v2/apps" -X GET -H "Content-Type: application/x-www-form-urlencoded" -d "q=name:${APP_NAME}&q=space_guid:${SPACE_GUID}" | jq -r '.resources[0].entity.routes_url')
  
  HOST=$(cf curl $ROUTES_URL -X GET -H "Content-Type: application/x-www-form-urlencoded" | jq -r '.resources[0].entity.host')
  
  echo "https://$HOST.$APP_DOMAIN" > app-url/app-url
}

loginAndTargetSpace() {
  cf api $CF_API --skip-ssl-validation && \
  cf auth $CF_USER $CF_PASSWORD
  
  cf create-space -o $CF_ORG $CF_SPACE
  cf target -o $CF_ORG -s $CF_SPACE

  # TODO - return error
}

pushApplication() {
  PARAMS="--no-start -p $CF_PATH $APP_NAME -d $APP_DOMAIN -b $BUILDPACK -f $CONFIG_FOLDER/manifest.yml"

  if [ ! -z "$APP_HOSTNAME" ]; then
    PARAMS="$PARAMS -n $APP_HOSTNAME"
  else
    PARAMS="$PARAMS --random-route"
  fi

  cf push $PARAMS

  if [ ! -z "$DB_NAME" ]; then
    cf bind-service $APP_NAME $DB_NAME
  fi

  cf start $APP_NAME

  # TODO - return error
}

# TODO - Check for errors
loginAndTargetSpace

# TODO - Check for errors
cleanSpace

createService

# TODO - Check for errors
pushApplication

exportHost