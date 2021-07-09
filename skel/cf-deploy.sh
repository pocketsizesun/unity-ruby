#!/bin/sh

STACK_NAME="dg-service-<%= @app_standard_name %>"

aws cloudformation deploy \
  --template-file aws-cf-template.yml \
  --stack-name $STACK_NAME
