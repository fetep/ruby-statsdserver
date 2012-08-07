#!/bin/sh

if [ "$1" = "default" ]; then
    sysctl -w net.core.rmem_max=131071
    sysctl -w net.core.rmem_default=126976
else
    sysctl -w net.core.rmem_max=10485760
    sysctl -w net.core.rmem_default=10485760
fi

