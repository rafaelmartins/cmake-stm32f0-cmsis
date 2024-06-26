# SPDX-FileCopyrightText: 2023-2024 Rafael G. Martins <rafael@rafaelmartins.eng.br>
# SPDX-License-Identifier: BSD-3-Clause

cmake_minimum_required(VERSION 3.17)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR})

set(CMAKE_TOOLCHAIN_FILE "${CMAKE_CURRENT_LIST_DIR}/stm32-gcc.cmake")

function(stm32f0_target_set_mcu target mcu)
    if(TARGET _stm32f0_target_set_mcu_${target})
        message(WARNING "stm32f0_target_set_mcu(${target}) already called, ignoring.")
        return()
    endif()
    add_library(_stm32f0_target_set_mcu_${target} INTERFACE)

    if(NOT DEFINED CMAKE_C_COMPILER_ID)
        message(FATAL_ERROR "Missing C compiler, please enable C language in your CMakeLists.txt.")
    endif()

    if(NOT DEFINED CMAKE_ASM_COMPILER_ID)
        message(FATAL_ERROR "Missing ASM compiler, please enable ASM language in CMake.")
    endif()

    if((NOT CMAKE_C_COMPILER_ID STREQUAL "GNU") OR (NOT CMAKE_ASM_COMPILER_ID STREQUAL "GNU"))
        message(FATAL_ERROR "Unsupported compiler, please use GCC (https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads)")
    endif()

    string(SUBSTRING ${mcu} 0 9 mcu_prefix)
    string(TOLOWER ${mcu_prefix} mcu_lower)
    string(TOUPPER ${mcu_prefix} mcu_upper)

    if(NOT ${mcu_lower} MATCHES "^stm32f0(30|31|38|42|48|51|58|70|71|72|78|91|98)$")
        message(FATAL_ERROR "Unsupported STM32F0 microcontroller: ${mcu}")
    endif()

    string(SUBSTRING ${mcu} 10 11 mcu_size)

    if(EXISTS ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../vendor/cmsis_device_f0/src/startup_${mcu_lower}x${mcu_size}.s)
        target_sources(${target} PRIVATE
            ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../vendor/cmsis_device_f0/src/startup_${mcu_lower}x${mcu_size}.s
            ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../vendor/cmsis_device_f0/src/system_stm32f0xx.c
        )

        target_compile_definitions(${target} PRIVATE
            ${mcu_upper}x${mcu_size}=1
            STM32F0=1
            STM32F0xx=1
        )
    else()
        target_sources(${target} PRIVATE
            ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../vendor/cmsis_device_f0/src/startup_${mcu_lower}xx.s
            ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../vendor/cmsis_device_f0/src/system_stm32f0xx.c
        )

        target_compile_definitions(${target} PRIVATE
            ${mcu_upper}xx=1
            STM32F0=1
            STM32F0xx=1
        )
    endif()

    target_include_directories(${target} PRIVATE
        ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../vendor/cmsis_core/include
        ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../vendor/cmsis_device_f0/include
    )

    target_compile_options(${target} PRIVATE
        -mcpu=cortex-m0
        -mthumb
    )

    target_link_options(${target} PRIVATE
        -mcpu=cortex-m0
        -mthumb
        -specs=nano.specs
        -Wl,--gc-sections
        -Wl,--no-warn-rwx-segments
    )
endfunction()

function(stm32f0_target_generate_map target)
    if(TARGET _stm32f0_target_generate_map_${target})
        message(WARNING "stm32f0_target_generate_map(${target}) already called, ignoring.")
        return()
    endif()
    add_library(_stm32f0_target_generate_map_${target} INTERFACE)

    target_link_options(${target} PRIVATE
        "-Wl,-Map,$<TARGET_FILE:${target}>.map"
    )

    set_property(TARGET ${target}
        APPEND
        PROPERTY ADDITIONAL_CLEAN_FILES "$<TARGET_FILE:${target}>.map"
    )
endfunction()

function(stm32f0_target_generate_bin target)
    if(TARGET ${target}-bin)
        message(WARNING "stm32f0_target_generate_bin(${target}) already called, ignoring.")
        return()
    endif()

    if(NOT ARM_OBJCOPY)
        message(WARNING "ARM objcopy not installed. ignoring bin generation.")
        return()
    endif()

    add_custom_command(
        OUTPUT ${target}.bin
        COMMAND "${ARM_OBJCOPY}" -O binary "$<TARGET_FILE:${target}>" "${target}.bin"
        DEPENDS $<TARGET_FILE:${target}>
    )

    add_custom_target(${target}-bin
        ALL
        DEPENDS ${target}.bin
    )
endfunction()

function(stm32f0_target_generate_ihex target)
    if(TARGET ${target}-ihex)
        message(WARNING "stm32f0_target_generate_ihex(${target}) already called, ignoring.")
        return()
    endif()

    if(NOT ARM_OBJCOPY)
        message(WARNING "ARM objcopy not installed. ignoring ihex generation.")
        return()
    endif()

    add_custom_command(
        OUTPUT ${target}.hex
        COMMAND "${ARM_OBJCOPY}" -O ihex "$<TARGET_FILE:${target}>" "${target}.hex"
        DEPENDS $<TARGET_FILE:${target}>
    )

    add_custom_target(${target}-ihex
        ALL
        DEPENDS ${target}.hex
    )
endfunction()

function(stm32f0_target_generate_dfu target)
    if(TARGET ${target}-dfu)
        message(WARNING "stm32f0_target_generate_dfu(${target}) already called, ignoring.")
        return()
    endif()

    find_program(DFUSE_PACK dfuse-pack)
    if(NOT DFUSE_PACK)
        message(WARNING "dfuse-pack not installed. ignoring DFU generation.")
        return()
    endif()

    if(NOT TARGET ${target}-ihex)
        message(FATAL_ERROR "stm32f0_target_generate_dfu() depends on IHEX file generated by stm32f0_target_generate_ihex()")
    endif()

    add_custom_command(
        OUTPUT ${target}.dfu
        COMMAND "${DFUSE_PACK}" -i "${target}.hex" "${target}.dfu"
        DEPENDS ${target}.hex
    )

    add_custom_target(${target}-dfu
        ALL
        DEPENDS ${target}.dfu
    )
endfunction()

function(stm32f0_target_show_size target)
    if(TARGET _stm32f0_target_show_size_${target})
        message(WARNING "stm32f0_target_show_size(${target}) already called, ignoring.")
        return()
    endif()
    add_library(_stm32f0_target_show_size_${target} INTERFACE)

    if(NOT ARM_SIZE)
        return()
    endif()

    add_custom_command(
        TARGET ${target}
        POST_BUILD
        COMMAND "${ARM_SIZE}" --format=berkeley "$<TARGET_FILE:${target}>"
    )
endfunction()

function(stm32f0_target_set_linker_script target script)
    if(TARGET _stm32f0_target_set_linker_script_${target})
        message(WARNING "stm32f0_target_set_linker_script(${target}) already called, ignoring.")
        return()
    endif()
    add_library(_stm32f0_target_set_linker_script_${target} INTERFACE)

    target_link_options(${target} PRIVATE
        "-T${script}"
    )
endfunction()

function(stm32f0_target_set_hse_clock target frequency)
    if(TARGET _stm32f0_target_set_hse_clock_${target})
        message(WARNING "stm32f0_target_set_hse_clock(${target}) already called, ignoring.")
        return()
    endif()
    add_library(_stm32f0_target_set_hse_clock_${target} INTERFACE)

    target_compile_definitions(${target} PRIVATE
        HSE_VALUE=${frequency}
    )
endfunction()

function(_stm32f0_stlink_variables)
    find_program(ST_FLASH st-flash)
    if(NOT ST_FLASH)
        message(WARNING "st-flash not installed, ignoring.")
        return()
    endif()

    set(STLINK_RESET "$ENV{STLINK_RESET}" CACHE BOOL "stlink tools reset")
    if(STLINK_RESET)
        set(STLINK_RESET_ARG "--reset" PARENT_SCOPE)
    endif()

    set(STLINK_CONNECT_UNDER_RESET "$ENV{STLINK_CONNECT_UNDER_RESET}" CACHE BOOL "stlink tools connect under reset")
    if(STLINK_CONNECT_UNDER_RESET)
        set(STLINK_CONNECT_UNDER_RESET_ARG "--connect-under-reset" PARENT_SCOPE)
    endif()

    set(STLINK_HOTPLUG "$ENV{STLINK_HOTPLUG}" CACHE BOOL "stlink tools hot plug")
    if(STLINK_HOTPLUG)
        set(STLINK_HOTPLUG_ARG "--hot-plug" PARENT_SCOPE)
    endif()

    set(STLINK_FREQ "$ENV{STLINK_FREQ}" CACHE STRING "stlink tools frequency in khz")
    if(NOT STLINK_FREQ STREQUAL "")
        set(STLINK_FREQ_ARG "--freq=${STLINK_FREQ}" PARENT_SCOPE)
    endif()

    set(STLINK_SERIAL "$ENV{STLINK_SERIAL}" CACHE STRING "stlink tools serial number (from st-info --serial)")
    if(NOT STLINK_SERIAL STREQUAL "")
        set(STLINK_SERIAL_ARG "--serial=${STLINK_SERIAL}" PARENT_SCOPE)
    endif()
endfunction()

function(stm32f0_target_stlink_write target)
    if(TARGET ${target}-stlink-write)
        message(WARNING "stm32f0_target_stlink_write(${target}) already called, ignoring.")
        return()
    endif()

    if(NOT TARGET ${target}-ihex)
        message(FATAL_ERROR "stm32f0_target_stlink_write(${target}) depends on IHEX file generated by stm32f0_target_generate_ihex()")
    endif()

    _stm32f0_stlink_variables()

    add_custom_target(${target}-stlink-write
        "${ST_FLASH}"
            ${STLINK_RESET_ARG}
            ${STLINK_CONNECT_UNDER_RESET_ARG}
            ${STLINK_HOTPLUG_ARG}
            ${STLINK_FREQ_ARG}
            ${STLINK_SERIAL_ARG}
            --format ihex
            write "${target}.hex"
        DEPENDS ${target}.hex
        USES_TERMINAL
    )
endfunction()

function(stm32f0_add_stlink_targets)
    if(TARGET st-flash-erase)
        message(WARNING "stm32f0_add_stlink_targets already called, ignoring.")
        return()
    endif()

    _stm32f0_stlink_variables()

    add_custom_target(stlink-erase
        "${ST_FLASH}"
            ${STLINK_CONNECT_UNDER_RESET_ARG}
            ${STLINK_HOTPLUG_ARG}
            ${STLINK_FREQ_ARG}
            ${STLINK_SERIAL_ARG}
            erase
        USES_TERMINAL
    )

    add_custom_target(stlink-reset
        "${ST_FLASH}"
            ${STLINK_FREQ_ARG}
            ${STLINK_SERIAL_ARG}
            reset
        USES_TERMINAL
    )
endfunction()
