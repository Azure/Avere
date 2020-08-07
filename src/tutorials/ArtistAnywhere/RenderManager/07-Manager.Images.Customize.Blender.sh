#!/bin/bash

set -ex

storageDirectory='/mnt/scenes/Blender/EEVEE'
mkdir -p $storageDirectory

fileName='color-vortex.blend'
if [ ! -f $storageDirectory/$fileName ]; then
    curl -L -o $storageDirectory/$fileName 'https://download.blender.org/demo/color_vortex.blend'
fi

fileName='mr-elephant.blend'
if [ ! -f $storageDirectory/$fileName ]; then
    curl -L -o $storageDirectory/$fileName 'https://download.blender.org/demo/eevee/mr_elephant/mr_elephant.blend'
fi

fileName='race-spaceship.blend'
if [ ! -f $storageDirectory/$fileName ]; then
    curl -L -o $storageDirectory/$fileName 'https://download.blender.org/demo/eevee/race_spaceship/race_spaceship.blend'
fi

storageDirectory='/mnt/scenes/Blender/Cycles'
mkdir -p $storageDirectory

fileName='barbershop-cpu.blend'
if [ ! -f $storageDirectory/$fileName ]; then
    curl -L -o $storageDirectory/$fileName 'https://svn.blender.org/svnroot/bf-blender/trunk/lib/benchmarks/cycles/barbershop_interior/barbershop_interior_cpu.blend'
fi

fileName='barbershop-gpu.blend'
if [ ! -f $storageDirectory/$fileName ]; then
    curl -L -o $storageDirectory/$fileName 'https://svn.blender.org/svnroot/bf-blender/trunk/lib/benchmarks/cycles/barbershop_interior/barbershop_interior_gpu.blend'
fi

fileName='benchmark.zip'
if [ ! -f $storageDirectory/$fileName ]; then
    curl -L -o $storageDirectory/$fileName 'https://download.blender.org/demo/test/benchmark.zip'
fi

fileName='bmw.zip'
if [ ! -f $storageDirectory/$fileName ]; then
    curl -L -o $storageDirectory/$fileName 'https://download.blender.org/demo/test/BMW27_2.blend.zip'
fi
