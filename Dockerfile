#######################################################################
# Docker image generation for cross-compiling Qt 6 for Raspberry Pi 3 #
#######################################################################

# Based on: https://wiki.qt.io/Cross-Compile_Qt_6_for_Raspberry_Pi
#               |- https://wiki.qt.io/Building_Qt_6_from_Git
#           https://github.com/PhysicsX/QTonRaspberryPi/blob/main/README.md

# Building Qt does not work on the newest Ubuntu (linker error), so let's use Ubuntu 20.04
FROM ubuntu:focal

#######################################################################
#                 PLEASE CUSTOMIZE THIS SECTION
#######################################################################
# The Qt version to build
ARG QT_VERSION=6.2.4
# The Qt modules to build
# I use QtQuick with QML, so the following three modules need to be built
ARG QT_MODULES=qtbase,qtshadertools,qtdeclarative
# How many cores to use for parallel builds
ARG PARALLELIZATION=12
# Your time zone (optionally change it)
ARG TZ=Chicago

ARG buildKernel=false

#Is the Wombat available to connect over ssh?
ARG wombatAvailable=true

#SSH address for Wombat
ARG WOMBAT_IP_ADDRESS="192.168.86.206"


#Branch Selection
ARG libwallabyBranch="refactor"
ARG botuiBranch="erinQt6Upgrade"

#######################################################################

ARG CMAKE_GIT_HASH=6b24b9c7fca09a7e5ca4ae652f4252175e168bde
ARG RPI_DEVICE=linux-rasp-pi3-g++

#############################
# Prepare and update Ubuntu #
#############################
RUN apt update \
 && apt upgrade -y \
 && apt install openssl -y \
 && apt install sudo


 #Install OpenGL Dependencies (chatGPT suggested this as a fix for a qt error)
 RUN sudo apt install -y libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev


#Add user qtpi with password raspberry
RUN useradd -G sudo -m qtpi -p "$(openssl passwd -1 raspberry)" \
 && echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER qtpi
WORKDIR /home/qtpi

#############################
# Install required packages #
#############################
# Qt
RUN echo "raspberry" | sudo -S apt install -y make build-essential libclang-dev ninja-build gcc git bison python3 gperf 
RUN sudo DEBIAN_FRONTEND=noninteractive TZ="${TZ}" apt install -y pkg-config libfontconfig1-dev libfreetype6-dev libx11-dev libx11-xcb-dev libxext-dev libxfixes-dev libxi-dev libxrender-dev libxcb1-dev libxcb-glx0-dev libxcb-keysyms1-dev libxcb-image0-dev libxcb-shm0-dev libxcb-icccm4-dev libxcb-sync-dev libxcb-xfixes0-dev libxcb-shape0-dev libxcb-randr0-dev libxcb-render-util0-dev libxcb-util-dev libxcb-xinerama0-dev libxcb-xkb-dev libxkbcommon-dev libxkbcommon-x11-dev libatspi2.0-dev libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev
# cross-compiler toolchain \
RUN sudo apt install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
# package for building CMake \
 && sudo apt install -y libssl-dev \
# data transfer \
 && sudo apt install -y rsync wget

#######################
# Create working dirs #
#######################
RUN mkdir rpi-sysroot rpi-sysroot/usr rpi-sysroot/opt \
 && mkdir qt-host qt-raspi qthost-build qtpi-build

################################################
# Copy sysroot into the image and fix symlinks #
################################################
COPY --chown=qtpi:qtpi rpi-sysroot /home/qtpi/rpi-sysroot

RUN wget https://raw.githubusercontent.com/riscv/riscv-poky/master/scripts/sysroot-relativelinks.py \
 && chmod u+x sysroot-relativelinks.py \
 && python3 sysroot-relativelinks.py rpi-sysroot

##################################
# Build a CMake version that can #
# cope with our toolchain.cmake  #
##################################
RUN git clone https://github.com/Kitware/CMake.git \
 && cd CMake \
 && git checkout ${CMAKE_GIT_HASH} \
 && ./bootstrap \
 && make \
 && sudo make install \
 && cd .. \
 && rm -rf CMake

####################
# Clone Qt sources #
####################
RUN git clone git://code.qt.io/qt/qt5.git qt6 \
 && cd qt6 \
 && git checkout v${QT_VERSION} \
 && perl init-repository --module-subset=${QT_MODULES}
# Leave the qt6 folder in case you must look up sources later

#################
# Qt HOST build #
#################
RUN cd qthost-build \
 && ../qt6/configure -prefix /home/qtpi/qt-host \
 && cmake --build . --parallel ${PARALLELIZATION} \
 && cmake --install . \
 && cd .. \
 && rm -rf qthost-build

###################
# Qt TARGET build #
###################
COPY --chown=qtpi:qtpi toolchain.cmake /home/qtpi/toolchain.cmake

RUN cd qtpi-build \
 && ../qt6/configure -release -opengl es2 -nomake examples -nomake tests -qt-host-path /home/qtpi/qt-host -extprefix /home/qtpi/qt-raspi -prefix /usr/local/lib -device ${RPI_DEVICE} -device-option CROSS_COMPILE=aarch64-linux-gnu- -- -DCMAKE_TOOLCHAIN_FILE=/home/qtpi/toolchain.cmake -DQT_FEATURE_xcb=ON -DFEATURE_xcb_xlib=ON -DQT_FEATURE_xlib=ON \
 && cmake --build . --parallel ${PARALLELIZATION} \
 && cmake --install . \
 && cd .. \
 && rm -rf qtpi-build

###################
#    Libwallaby   #
###################
#Note: The shared libaries would probably be better installed on the host level instead of the container level, but this is easier logistically.
RUN sudo apt-get update \
&& sudo apt-get install libzbar-dev libopencv-dev libjpeg-dev python-dev doxygen swig -y \
&& git clone https://github.com/kipr/libwallaby --branch ${libwallabyBranch} \
&& cd libwallaby \
&& /home/qtpi/qt-raspi/bin/qt-cmake -Bbuild \
-DCMAKE_TOOLCHAIN_FILE=$(pwd)/toolchain/aarch64-linux-gnu.cmake \
-DCMAKE_C_COMPILER=/usr/bin/aarch64-linux-gnu-gcc-9 \
-DCMAKE_CXX_COMPILER=/usr/bin/aarch64-linux-gnu-g++-9 \
-DCMAKE_SYSROOT=/home/qtpi/rpi-sysroot .  \
&& cd build \
&& make -j${PARALLELIZATION} \
&& sudo make install \
&& cd ../.. #return to start for next instructions

###################
#    Libkar       #
###################
RUN git clone https://github.com/kipr/libkar --branch erinQt6Upgrade \
&& cd libkar \
&& mkdir build \
&& cd build \
&& /home/qtpi/qt-raspi/bin/qt-cmake ..  \
&& make -j${PARALLELIZATION} \
&& sudo make install \
&& cd ../.. #return to start for next instructions


###################
#    pCompiler    #
###################
RUN git clone https://github.com/kipr/pcompiler --branch erinQt6Upgrade  \
&& cd pcompiler \
&& mkdir build \
&& cd build \
&& /home/qtpi/qt-raspi/bin/qt-cmake -Ddocker_cross=ON ..   \
&& make -j${PARALLELIZATION} \
&& sudo make install


#Move the shared library to the appropriate spot
# RUN cd .. \
# && cp lib/libpcompiler.so /usr/lib \
# && cd .. #return to start for next instructions

###################
#      Botui      #
###################
RUN git clone https://github.com/kipr/botui --branch ${botuiBranch} \
&& cd botui \
&& mkdir build \
&& cd build \
&& /home/qtpi/qt-raspi/bin/qt-cmake -Ddocker_cross=ON .. \
&& make -j${PARALLELIZATION} \
&& sudo make install \
&& cd ../.. #return to start for next instructions

###################
#      Cpack      #
###################
RUN WOMBAT_IP=${WOMBAT_IP_ADDRESS} \
&& cd libkar/build/ \
&& sudo cpack  \
&&  cd ../.. \
&& cd pcompiler/build/ \
&& sudo cpack  \
&&  cd ../.. \
&& cd libwallaby/build/ \
&& sudo cpack  \
&&  cd ../.. \
&& cd botui/build/ \
&& sudo cpack  \
&&  cd ../.. 
# RUN echo ${WOMBAT_IP}
# RUN if [ "$wombatAvailable" = "true" ]; then \
#     scp libkar/build/libkar-0.1.1-Linux.deb kipr@${WOMBAT_IP}:~/libkar-0.1.1-Linux.deb \
#     && scp pcompiler/build/pcompiler-0.1.1-Linux.deb kipr@${WOMBAT_IP}:~/pcompiler-0.1.1-Linux.deb \
#     && scp libwallaby/build/kipr-1.0.0-Linux.deb kipr@${WOMBAT_IP}:~/kipr-1.0.0-Linux.deb \
#     && scp botui/build/botui-0.1.1-Linux.deb kipr@${WOMBAT_IP}:~/botui-0.1.1-Linux.deb; \
#     fi

########################################
# Syncing the Qt files back to the RPi #
# is done in the docker container      #
########################################
COPY --chown=qtpi:qtpi _copyQtToRPi.sh /home/qtpi/copyQtToRPi.sh
