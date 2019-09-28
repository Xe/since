#!/usr/bin/env bash

GIT_COMMIT="$(git rev-parse HEAD)"

(cd .. && docker build -t xena/since:$GIT_COMMIT . && docker push xena/since:$GIT_COMMIT)

kubens apps
sed -e "s/\${IMAGE}/xena\/since:${GIT_COMMIT}/" since.yml | kubectl apply -f -
