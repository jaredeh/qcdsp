# Install Android SDK
follow instructions for Android SDK Command-line Tools
https://developer.android.com/tools/sdkmanager


ubuntu 22.04
apt -y update
apt -y install bc sudo librtmp1 libsasl2-2 libsqlite3-0
cd app
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
apt install ./downloads/QualcommPackageManager3.3.0.107.0.Linux-x86.deb

qpm-cli
Download QPM3
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

/opt/qcom/QPM3/bin/qpm-cli --extract qualcomm_ai_engine_direct

qpm-cli --login jared@resurgentech.com --password 9NS!3QlF^C#MxKUg

# OnePlus 3T
Enable Developer Options like normal
Enable OEM  Unlocking
Boot to Fastboot power and vol down
change language to English
advanced.
reboot to fastboot
fastboot oem unlock

GPU 100     0m19.08s real     0m01.87s user     0m04.90s system
CPU 100     0m35.72s real     3m14.07s user     0m25.63s system
AIP 100     0m09.84s real     0m02.71s user     0m03.89s system
DSP 100     0m09.75s real     0m02.89s user     0m03.54s system

GPU 1       0m02.30s real     0m00.77s user     0m01.52s syste
CPU 1       0m02.60s real     0m02.42s user     0m02.20s system
AIP 1       0m03.92s real     0m02.21s user     0m01.24s system
DSP 1       0m03.88s real     0m02.24s user     0m01.17s system

DSP 1       0m03.88s real     0m02.24s user     0m01.17s system
DSP 10      0m04.42s real     0m02.33s user     0m01.38s system
DSP 100     0m09.75s real     0m02.89s user     0m03.54s system
DSP 1000    1m03.68s real     0m07.82s user     0m27.43s system

AIP 1       0m03.92s real     0m02.21s user     0m01.24s system
AIP 10      
AIP 100     
AIP 1000    1m03.65s real     0m09.19s user     0m25.50s system
