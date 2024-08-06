#!/bin/bash
adb kill-server
adb -a -P 5037 start-server

TAG="$1"
if [ -z "$TAG" ]; then
    TAG="snpe1:latest"
fi
CMD="docker run -it --rm -v $(pwd):/app --add-host=host.docker.internal:host-gateway resurgentech_local/$TAG"
echo "--------------------------------------------------------------------------------------------------"
echo "-- '$CMD'"
echo "--------------------------------------------------------------------------------------------------"
$CMD
