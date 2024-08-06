#!/bin/bash

CMD="$1"
shift

VALID_CMDS="prep install run clean"
if [[ ! $VALID_CMDS =~ (^|[[:space:]])$CMD($|[[:space:]]) ]]; then
    echo "Error: Invalid command."
    echo "  Valid commands are: $VALID_CMDS"
    exit 1
fi

if [ "$CMD" == "prep" ]; then
  CMD_PREP="true"
elif [ "$CMD" == "install" ]; then
  CMD_PREP="true"
  CMD_INSTALL="true"
elif [ "$CMD" == "run" ]; then
  CMD_RUN="true"
  CMD_CLASSIFY="true"
elif [ "$CMD" == "clean" ]; then
  CMD_CLEAN="true"
fi

# defaults
SNPE_VERSION="snpe1"
RUNFLAG="--use_dsp"
TIMED_CMDS="0"

VALID_OPTS="--local --debug"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --local)
      if [ ! -z "$CMD" ]; then
        CMD_LOCALRUN="true"
        CMD_RUN=""
      fi
      shift
      ;;
    --noclassify)
      OPT_NOCLASSIFY="true"
      CMD_CLASSIFY=""
      shift
      ;;
    --debug)
      OPT_DEBUG="true"
      shift
      ;;
    --snpe2)
      SNPE_VERSION="snpe2"
      shift
      ;;
    --use_cpu)
      RUNFLAG=""
      shift
      ;;
    --use_gpu)
      RUNFLAG="--use_gpu"
      shift
      ;;
    --use_aip)
      RUNFLAG="--use_aip"
      shift
      ;;
    --use_dsp)
      RUNFLAG="--use_dsp"
      shift
      ;;
    --time)
      TIMED_CMDS="$(($2 - 1))"
      shift 2
      ;;
    *)
      echo "Error: Unknown option $1"
      echo "  Valid options are: $VALID_OPTS"
      exit 1
      ;;
  esac
done

if [ ! -z "$OPT_DEBUG" ]; then
  echo "CMD_PREP:       $CMD_PREP"
  echo "CMD_INSTALL:    $CMD_INSTALL"
  echo "CMD_CLASSIFY:   $CMD_CLASSIFY"
  echo "CMD_CLEAN:      $CMD_CLEAN"
  echo "CMD_RUN:        $CMD_RUN"
  echo "CMD_LOCALRUN:   $CMD_LOCALRUN"
  echo "OPT_DEBUG:      $OPT_DEBUG"
  echo "OPT_NOCLASSIFY: $OPT_NOCLASSIFY"
  echo "SNPE_VERSION:   $SNPE_VERSION"
  echo "RUNFLAG:        $RUNFLAG"
  echo "TIMED_CMDS:     $TIMED_CMDS"
fi

source $SNPE_ROOT/bin/envsetup.sh

DEMO_NAME=snpe_vgg_demo
if [ "$SNPE_VERSION" == "snpe1" ]; then
  VGG_DIR=$SNPE_ROOT/models/VGG
  ARM_CROSS_COMPILE_DIR=aarch64-android-clang8.0
elif [ "$SNPE_VERSION" == "snpe2" ]; then
  VGG_DIR=$SNPE_ROOT/examples/Models/VGG
  ARM_CROSS_COMPILE_DIR=aarch64-linux-android
fi
DEMO_DIR=$VGG_DIR/$DEMO_NAME

ANDROID_DEMO_DIR=/data/local/tmp/$DEMO_NAME

# Prep the files
if [ ! -z "$CMD_PREP" ]; then
  mkdir -p $DEMO_DIR
  pushd $DEMO_DIR > /dev/null
    if [ ! -f vgg16.dlc ]; then
      if [ ! -f /app/tmp/vgg16.onnx ]; then
        wget https://s3.amazonaws.com/onnx-model-zoo/vgg/vgg16/vgg16.onnx
        cp vgg16.onnx /app/tmp/vgg16.onnx
      else
        cp /app/tmp/vgg16.onnx .
      fi
    fi
  popd > /dev/null

  mkdir -p $DEMO_DIR/data
  pushd $DEMO_DIR/data > /dev/null
    if [ ! -f /app/tmp/kitten.jpg ]; then
      wget https://s3.amazonaws.com/model-server/inputs/kitten.jpg
      cp kitten.jpg /app/tmp/kitten.jpg
    else
      cp /app/tmp/kitten.jpg .
    fi
    if [ ! -f /app/tmp/synset.txt ]; then
      wget https://s3.amazonaws.com/onnx-model-zoo/synset.txt
      cp synset.txt /app/tmp/synset.txt
    else
      cp /app/tmp/synset.txt .
    fi
  popd > /dev/null

  pushd $VGG_DIR > /dev/null
    if [ ! -f "$DEMO_DIR/kitten.raw" ]; then
      mkdir -p $DEMO_DIR/data/cropped
      python3 scripts/create_VGG_raws.py -i $DEMO_DIR/data/ -d $DEMO_DIR/data/cropped/
      mv $DEMO_DIR/data/cropped/kitten.raw $DEMO_DIR/kitten.raw
      rm -rf $DEMO_DIR/data/cropped
      echo "kitten.raw" > $DEMO_DIR/input_list.txt
    fi
  popd > /dev/null

  pushd $DEMO_DIR > /dev/null
    if [ ! -f vgg16.dlc ]; then
      mkdir -p dlc
      snpe-onnx-to-dlc -i vgg16.onnx -o dlc/vgg16_raw.dlc
      #snpe-dlc-quant --input_dlc dlc/vgg16_raw.dlc --input_list input_list.txt --output_dlc dlc/vgg16_quant.dlc
      snpe-dlc-quantize --input_dlc dlc/vgg16_raw.dlc \
                        --input_list input_list.txt \
                        --output_dlc dlc/vgg16_quant.dlc
      cp dlc/vgg16_quant.dlc vgg16.dlc
      #snpe-dlc-graph-prepare --input_dlc dlc/vgg16_quant.dlc --input_list input_list.txt --output_dlc vgg16.dlc
      rm -rf dlc
      rm vgg16.onnx
    fi
  popd > /dev/null
fi

# Clean up files
if  [ ! -z "$CMD_CLEAN" ]; then
  rm -rf $DEMO_DIR
  adb root
  adb shell "rm -rf $ANDROID_DEMO_DIR"
fi


# Install to Android device
if [ ! -z "$CMD_INSTALL" ]; then
  rm -rf $DEMO_DIR/bin $DEMO_DIR/lib $DEMO_DIR/dsp_lib $DEMO_DIR/output
  mkdir -p $DEMO_DIR/output
  cp -r $SNPE_ROOT/bin/$ARM_CROSS_COMPILE_DIR $DEMO_DIR
  mv $DEMO_DIR/$ARM_CROSS_COMPILE_DIR $DEMO_DIR/bin
  cp -r $SNPE_ROOT/lib/$ARM_CROSS_COMPILE_DIR $DEMO_DIR
  mv $DEMO_DIR/$ARM_CROSS_COMPILE_DIR $DEMO_DIR/lib
  if [ "$SNPE_VERSION" == "snpe1" ]; then
    cp -r $SNPE_ROOT/lib/dsp $DEMO_DIR
    mv $DEMO_DIR/dsp $DEMO_DIR/dsp_lib/
  elif [ "$SNPE_VERSION" == "snpe2" ]; then
    cp -r $SNPE_ROOT/lib/hexagon-v66/unsigned $DEMO_DIR
    mv $DEMO_DIR/unsigned $DEMO_DIR/dsp_lib/
  fi
  adb root
  adb shell "rm -rf $ANDROID_DEMO_DIR"
  adb push $DEMO_DIR /data/local/tmp/
  adb shell "mkdir $ANDROID_DEMO_DIR/output"
  echo "install"
fi

# Run on Android device
if [ ! -z "$CMD_RUN" ]; then
  echo "kitten.raw" > $DEMO_DIR/input_list.txt
  for i in $(seq 1 $TIMED_CMDS); do
    echo "kitten.raw" >> $DEMO_DIR/input_list.txt
  done
  adb push $DEMO_DIR/input_list.txt $ANDROID_DEMO_DIR 
  CMD="cd $ANDROID_DEMO_DIR"
  CMD="$CMD && export LD_LIBRARY_PATH=$ANDROID_DEMO_DIR/lib"
  CMD="$CMD && export ADSP_LIBRARY_PATH=$ANDROID_DEMO_DIR/dsp_lib"
  CMD="$CMD && time ./bin/snpe-net-run --input_list input_list.txt --container vgg16.dlc --output_dir output $RUNFLAG"
  adb shell "$CMD"
  rm -rf $DEMO_DIR/output
  adb pull $ANDROID_DEMO_DIR/output/ $DEMO_DIR/
fi

# Run on local host machine
if [ ! -z "$CMD_LOCALRUN" ]; then
  pushd $DEMO_DIR > /dev/null
    rm -rf output
    mkdir -p output
    snpe-net-run --input_list input_list.txt --container vgg16.dlc --output_dir output
  popd > /dev/null
fi

# Look at results, run on local host machine
if [ ! -z "$CMD_CLASSIFY" ]; then
  pushd $VGG_DIR > /dev/null
    python3 scripts/show_vgg_classifications.py -i $DEMO_DIR/input_list.txt -o $DEMO_DIR/output/ -l $DEMO_DIR/data/synset.txt
  popd > /dev/null
fi
