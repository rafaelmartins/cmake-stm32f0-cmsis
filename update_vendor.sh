#!/bin/bash

set -e -o pipefail

CMSIS_CORE_VERSION="v5.6.0_cm0"
CMSIS_DEVICE_F0_VERSION="v2.3.7"

REPODIR="$(mktemp -d)"
trap 'rm -rf "${REPODIR}"' EXIT

git clone \
    -c advice.detachedHead=false \
    --depth=1 \
    --branch="${CMSIS_CORE_VERSION}" \
    "https://github.com/STMicroelectronics/cmsis_core.git" \
    "${REPODIR}/cmsis_core"

git clone \
    -c advice.detachedHead=false \
    --depth=1 \
    --branch="${CMSIS_DEVICE_F0_VERSION}" \
    "https://github.com/STMicroelectronics/cmsis_device_f0.git" \
    "${REPODIR}/cmsis_device_f0"

rm -rf ./vendor/
mkdir -p ./vendor/{cmsis_core/include,cmsis_device_f0/{src,include}}

cp \
    --verbose \
    "${REPODIR}"/cmsis_core/LICENSE.txt \
    ./vendor/LICENSE

cp \
    --verbose \
    "${REPODIR}"/cmsis_core/Core/Include/cmsis_compiler.h \
    "${REPODIR}"/cmsis_core/Core/Include/cmsis_gcc.h \
    "${REPODIR}"/cmsis_core/Core/Include/cmsis_version.h \
    "${REPODIR}"/cmsis_core/Core/Include/core_cm0.h \
    ./vendor/cmsis_core/include/

cp \
    --verbose \
    "${REPODIR}"/cmsis_device_f0/Include/stm32f0*.h \
    "${REPODIR}"/cmsis_device_f0/Include/system_stm32f0xx.h \
    ./vendor/cmsis_device_f0/include/

cp \
    --verbose \
    "${REPODIR}"/cmsis_device_f0/Source/Templates/gcc/startup_stm32f0*.s \
    "${REPODIR}"/cmsis_device_f0/Source/Templates/system_stm32f0xx.c \
    ./vendor/cmsis_device_f0/src/
