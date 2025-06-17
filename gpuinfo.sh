#!/bin/bash

echo
echo
cat /proc/version
echo
uname -r 
echo 
cat /etc/os-release 
echo 
sudo lshw -C video 
echo 
lspci -k | grep -A 2 -i "VGA" 
echo 
glxinfo | grep -iE 'vendor:|device:|version:' 
echo 
dpkg -l xserver-xorg-video-amdgpu 
echo
