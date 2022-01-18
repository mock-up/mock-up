#!/bin/bash

readonly TARGET_DIR="assets/live"

if [[ ! -d $TARGET_DIR ]]; then
  echo "[error] Not Found target directory ${TARGET_DIR}" >&2
  exit
fi

while true; do
  cli/main preview
  yq eval -o json ./assets/livecoding.yaml > ./assets/live/livecoding.json
done