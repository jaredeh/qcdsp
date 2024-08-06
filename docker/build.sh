#!/bin/bash
cd "$(dirname "$0")"

ORG="resurgentech_local"
TAG="latest"
VERSION="snpe1"


while [[ $# -gt 0 ]]; do
    case $1 in
        --tag)
            TAG="$2"
            shift 2
            ;;
        --org)
            ORG="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

if [ "$VERSION" == "snpe1" ]; then
    BUILD_SNPE1="true"
elif [ "$VERSION" == "snpe2" ]; then
    BUILD_SNPE2="true"
fi

function build_image() {
    local DF_SUFFIX="$1"
    local BASE_IMAGE="$2"
    local LORG="$3"
    local LTAG="$4"

    local CMD="docker build -t $LORG/$DF_SUFFIX:$LTAG --build-arg BASE_IMAGE=$BASE_IMAGE -f Dockerfile.$DF_SUFFIX ."
    echo "--------------------------------------------------------------------------------------------------"
    echo "-- '$CMD'"
    echo "--------------------------------------------------------------------------------------------------"
    $CMD
    echo "**************************************************************************************************"
}


if [ "$BUILD_SNPE1" == "true" ]; then
    build_image hexagon ubuntu:20.04 "$ORG" "20.04"
    build_image ndk "$ORG/hexagon:20.04" "$ORG" "20.04"
    build_image snpe1_files "$ORG/ndk:20.04" "$ORG" "$TAG"
    build_image snpe1_pip "$ORG/snpe1_files:$TAG" "$ORG" "$TAG"
    build_image snpe1_preq "$ORG/snpe1_pip:$TAG" "$ORG" "$TAG"
    build_image snpe1 "$ORG/snpe1_preq:$TAG" "$ORG" "$TAG"
fi
if [ "$BUILD_SNPE2" == "true" ]; then
    build_image hexagon ubuntu:22.04 "$ORG" "$TAG"
    build_image ndk "$ORG/hexagon:$TAG" "$ORG" "$TAG"
    build_image snpe2_files "$ORG/ndk:$TAG" "$ORG" "$TAG"
    build_image snpe2_pip "$ORG/snpe2_files:$TAG" "$ORG" "$TAG"
    build_image snpe2_preq "$ORG/snpe2_pip:$TAG" "$ORG" "$TAG"
    build_image snpe2 "$ORG/snpe2_preq:$TAG" "$ORG" "$TAG"
fi
