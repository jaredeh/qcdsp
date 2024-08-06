#

# Downloading files

## Android Command Line Tools
This is the command line tools for android, specifically the sdkmanager, which is required to downloading the rest of the sdk via the command line.

`commandlinetools-linux-11076708_latest.zip`

https://developer.android.com/studio#command-line-tools-only


## Qualcomm Hexagon DSP SDK
This is the hexagon dsp sdk, which is required to build hexagon binaries for the snapdragon DSPs.

`hexagon_sdk_lnx_3_5_installer_00006_1.zip`

https://developer.qualcomm.com/software/hexagon-dsp-sdk/tools

**NOTE - This may need to be updated to be like the SNPE SDK downloaded via QPM3**


## Qualcomm Package Manager 3
This is the new qualcomm package manager, which is required to install the rest of the sdk via the command line. Super finichy, and it requires a qualcomm account to use.

`QualcommPackageManager3.3.0.107.0.Linux-x86.deb`

https://qpm.qualcomm.com/#/main/tools/details/QPM3

## Qualcomm® Neural Processing SDK (SNPE2)

`snpe-2.25.0.240728.tar.gz`

https://qpm.qualcomm.com/#/main/tools/details/qualcomm_neural_processing_sdk

### Extracting the SNPE2 SDK
With Qualcomm Package Manager 3 installed, you can install the SNPE SDK by running the following command:
```
qpm-cli --login <username>
# will ask for password
qpm-cli --license-activate qualcomm_neural_processing_sdk
qpm-cli --extract qualcomm_neural_processing_sdk
```
Once installed you can repackage the sdk for use in docker.
```
cd /opt/qcom/aistack/qairt/2.25.0.240728
tar -czvf /tmp/snpe-2.25.0.240728.tar.gz *
```

## Qualcomm® Neural Processing SDK (SNPE1)

`snpe-1.68.0.zip`

https://developer.qualcomm.com/software/qualcomm-neural-processing-sdk/tools-archive

