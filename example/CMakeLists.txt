# SPDX-FileCopyrightText: 2023-2024 Rafael G. Martins <rafael@rafaelmartins.eng.br>
# SPDX-License-Identifier: BSD-3-Clause

cmake_minimum_required(VERSION 3.17)

include(../cmake/stm32f0-cmsis.cmake)

project(example C ASM)

add_executable(example
    main.c
)

target_compile_options(example PRIVATE
    -Wall
    -Wextra
    -Werror
)

set_property(TARGET example
    PROPERTY INTERPROCEDURAL_OPTIMIZATION TRUE
)

stm32f0_target_set_mcu(example stm32f042k6)
stm32f0_target_generate_map(example)
stm32f0_target_generate_ihex(example)
stm32f0_target_generate_dfu(example)
stm32f0_target_show_size(example)
stm32f0_target_set_linker_script(example ${CMAKE_CURRENT_SOURCE_DIR}/STM32F042K6Tx_FLASH.ld)
stm32f0_target_stlink_write(example)
stm32f0_add_stlink_targets()
