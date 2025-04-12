#!/bin/bash

# Check if the HUTTE_GIT_USER_NAME environment variable is set
if [ -z "$HUTTE_GIT_USER_NAME" ]; then
    echo "Error: HUTTE_GIT_USER_NAME variable is not set."
    exit 1
fi

# Replace the placeholder with the actual last name from the environment variable
sed "s/PLACEHOLDER_LAST_NAME/$HUTTE_GIT_USER_NAME/g" data/compositetest.json > data/composite_actual.json

echo "JSON file prepared with last name: $HUTTE_GIT_USER_NAME"