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
    --debug)
      OPT_DEBUG="true"
      shift
      ;;
    *)
      echo "Error: Unknown option $1"
      echo "  Valid options are: $VALID_OPTS"
      exit 1
      ;;
  esac
done

if [ ! -z "$OPT_DEBUG" ]; then
  echo "CMD_PREP:     $CMD_PREP"
  echo "CMD_INSTALL:  $CMD_INSTALL"
  echo "CMD_CLASSIFY: $CMD_CLASSIFY"
  echo "CMD_CLEAN:    $CMD_CLEAN"
  echo "CMD_RUN:      $CMD_RUN"
  echo "CMD_LOCALRUN: $CMD_LOCALRUN"
  echo "OPT_DEBUG:    $OPT_DEBUG"
fi

export ALT_SNPE_ROOT=/opt/snpe-1.68.0.3932

source $SNPE_ROOT/bin/envsetup.sh

EXAMPLE_DIR=$ALT_SNPE_ROOT/models/word_rnn
DEMO_NAME=word_rnn_demo
DEMO_DIR=$ALT_SNPE_ROOT/models/word_rnn/$DEMO_NAME
ANDROID_DEMO_DIR=/data/local/tmp/$DEMO_NAME


# Prep the files
if [ ! -z "$CMD_PREP" ]; then
  mkdir -p $DEMO_DIR
  pushd $EXAMPLE_DIR > /dev/null
    if [ ! -f word_rnn.dlc ]; then
      python3 $SNPE_ROOT/examples/Models/word_rnn/word_rnn.py --training_iter 5000
      export SNPE_ROOT=$ALT_SNPE_ROOT
      #export PYTHONPATH=$PYTHONPATH:$SNPE_ROOT/lib/python
      echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
      echo ""
      $ALT_SNPE_ROOT/bin/x86_64-linux-clang/snpe-tensorflow-to-dlc --input_network word_rnn.pb \
                             --input_dim Placeholder "1, 4, 1" \
                             --out_node "rnn/lstm_cell/mul_11" \
                             --output_path word_rnn.raw.dlc
      echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
      echo ""
      $ALT_SNPE_ROOT/bin/x86_64-linux-clang/snpe-dlc-quantize --input_dlc word_rnn.raw.dlc \
                        --input_list input_list.txt \
                        --output_dlc word_rnn.quant.dlc \
                        #--enable_htp
      echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
      echo ""
      cp word_rnn.quant.dlc word_rnn.dlc
      # $ALT_SNPE_ROOT/bin/x86_64-linux-clang/snpe-dlc-graph-prepare --input_dlc word_rnn.quant.dlc \
      #                        --input_list input_list.txt \
      #                        --output_dlc word_rnn.dlc \
      #                        #--htp_socs sm8250 \
      #                        #--htp_archs v66
    fi
  popd > /dev/null
fi

# Clean up files
if  [ ! -z "$CMD_CLEAN" ]; then
  rm -rf $DEMO_DIR
  rm -rf $EXAMPLE_DIR/*.dlc
  rm -rf $EXAMPLE_DIR/*.pb
  adb root
  adb shell "rm -rf $ANDROID_DEMO_DIR"
fi

# Install to Android device
if [ ! -z "$CMD_INSTALL" ]; then
  rm -rf $DEMO_DIR/bin $DEMO_DIR/lib $DEMO_DIR/dsp_lib $DEMO_DIR/output
  mkdir -p $DEMO_DIR/output
  cp -r $SNPE_ROOT/bin/aarch64-android $DEMO_DIR
  mv $DEMO_DIR/aarch64-android $DEMO_DIR/bin
  cp -r $SNPE_ROOT/lib/aarch64-android $DEMO_DIR
  mv $DEMO_DIR/aarch64-android $DEMO_DIR/lib
  cp -r $SNPE_ROOT/lib/hexagon-v66/unsigned $DEMO_DIR
  mv $DEMO_DIR/unsigned $DEMO_DIR/dsp_lib/
  cp $EXAMPLE_DIR/input_list.txt $DEMO_DIR
  cp $EXAMPLE_DIR/input.raw $DEMO_DIR
  cp $EXAMPLE_DIR/word_rnn.dlc $DEMO_DIR
  #cp $EXAMPLE_DIR/word_rnn_adb.sh $DEMO_DIR
  adb root
  adb shell "rm -rf $ANDROID_DEMO_DIR"
  adb push $DEMO_DIR /data/local/tmp/
  adb shell "mkdir $ANDROID_DEMO_DIR/output"
  echo "install"
fi

# Run on Android device
if [ ! -z "$CMD_RUN" ]; then
  adb shell "cd $ANDROID_DEMO_DIR \
             && export LD_LIBRARY_PATH=$ANDROID_DEMO_DIR/lib \
             && export ADSP_LIBRARY_PATH=$ANDROID_DEMO_DIR/dsp_lib \
             && ./bin/snpe-platform-validator --runtime aip --testRuntime"
  
  adb shell "cd $ANDROID_DEMO_DIR \
             && export LD_LIBRARY_PATH=$ANDROID_DEMO_DIR/lib \
             && export ADSP_LIBRARY_PATH=\"/system/lib/rfsa/adsp;/system/vendor/lib/rfsa/adsp;/dsp;$ANDROID_DEMO_DIR/dsp_lib\" \
             && ./bin/snpe-net-run \
                --input_list input_list.txt \
                --container word_rnn.dlc \
                --output_dir output \
                --debug \
                --use_dsp"
  rm -rf $DEMO_DIR/output
  adb pull $ANDROID_DEMO_DIR/output/ $DEMO_DIR/
fi

# Run on local host machine
if [ ! -z "$CMD_LOCALRUN" ]; then
  pushd $WORDRNN_DIR > /dev/null
    python3 inference.py
  popd > /dev/null
fi

