# ========================================================================================
# CMake Deploy Utilities (CDU) - Базовые утилиты
#
# Набор базовых утилит для логирования, валидации параметров и профилирования.
# Этот модуль предоставляет стандартизированные функции для вывода сообщений,
# проверки корректности переданных аргументов и измерения времени выполнения
# определённых операций в CMake.
# ========================================================================================

# Защита от повторного включения
if(CDU_UTILS_LOADED)
    return()
endif()
set(CDU_UTILS_LOADED TRUE)

# =g======================================================================================
# Настройка цветов для вывода в терминал
# ========================================================================================

if(NOT WIN32)
    string(ASCII 27 ESC)
    set(CDU_COLOR_RED "${ESC}[31m")
    set(CDU_COLOR_YELLOW "${ESC}[33m")
    set(CDU_COLOR_GREEN "${ESC}[32m")
    set(CDU_COLOR_CYAN "${ESC}[36m")
    set(CDU_COLOR_MAGENTA "${ESC}[35m")
    set(CDU_COLOR_RESET "${ESC}[0m")
else()
    set(CDU_COLOR_RED "")
    set(CDU_COLOR_YELLOW "")
    set(CDU_COLOR_GREEN "")
    set(CDU_COLOR_CYAN "")
    set(CDU_COLOR_MAGENTA "")
    set(CDU_COLOR_RESET "")
endif()

# ========================================================================================
# Функции логирования
# ========================================================================================

# Внутренняя функция для вывода сообщений
# _CDU_log(LEVEL <LEVEL> MESSAGE <MESSAGE>)
function(_CDU_log)
    cmake_parse_arguments(ARG "" "LEVEL;MESSAGE" "" ${ARGN})

    if(NOT ARG_MESSAGE)
        return()
    endif()

    set(LEVEL_MAP "ERROR;0;WARNING;1;INFO;2;DEBUG;3")
    list(FIND LEVEL_MAP "${CDU_LOG_LEVEL}" CURRENT_LEVEL_INDEX)
    list(FIND LEVEL_MAP "${ARG_LEVEL}" MSG_LEVEL_INDEX)

    if(CURRENT_LEVEL_INDEX GREATER_EQUAL MSG_LEVEL_INDEX)
        if(ARG_LEVEL STREQUAL "ERROR")
            message(FATAL_ERROR "${CDU_COLOR_RED}[CDU][ERROR]${CDU_COLOR_RESET} ${ARG_MESSAGE}")
        elseif(ARG_LEVEL STREQUAL "WARNING")
            message(WARNING "${CDU_COLOR_YELLOW}[CDU][WARNING]${CDU_COLOR_RESET} ${ARG_MESSAGE}")
        elseif(ARG_LEVEL STREQUAL "INFO")
            message(STATUS "${CDU_COLOR_GREEN}[CDU][INFO]${CDU_COLOR_RESET} ${ARG_MESSAGE}")
        elseif(ARG_LEVEL STREQUAL "DEBUG")
            if(CDU_DEBUG_MODE)
                message(STATUS "${CDU_COLOR_MAGENTA}[CDU][DEBUG]${CDU_COLOR_RESET} ${ARG_MESSAGE}")
            endif()
        endif()
    endif()
endfunction()

# Выводит сообщение об ошибке и прерывает выполнение.
function(CDU_error MESSAGE)
    _CDU_log(LEVEL "ERROR" MESSAGE "${MESSAGE}")
endfunction()

# Выводит предупреждение.
function(CDU_warning MESSAGE)
    _CDU_log(LEVEL "WARNING" MESSAGE "${MESSAGE}")
endfunction()

# Выводит информационное сообщение (STATUS).
function(CDU_info MESSAGE)
    _CDU_log(LEVEL "INFO" MESSAGE "${MESSAGE}")
endfunction()

# Выводит отладочное сообщение (только если CDU_DEBUG_MODE включен).
function(CDU_debug MESSAGE)
    _CDU_log(LEVEL "DEBUG" MESSAGE "${MESSAGE}")
endfunction()

# ========================================================================================
# Валидация параметров
# ========================================================================================

# Проверяет параметр на соответствие ожиданиям (тип, обязательность).
#
# Пример:
# validate_parameter(
#     NAME "MY_PARAM"
#     VALUE "${MY_PARAM_VALUE}"
#     TYPE "STRING"
#     REQUIRED
# )
function(CDU_validate_parameter)
    cmake_parse_arguments(ARG "REQUIRED" "NAME;VALUE;TYPE" "" ${ARGN})

    if(NOT ARG_NAME OR NOT ARG_TYPE)
        CDU_error("validate_parameter: parameters NAME and TYPE required.")
    endif()

    # Проверка на обязательность
    if(ARG_REQUIRED AND (NOT DEFINED ARG_VALUE OR ARG_VALUE STREQUAL ""))
        CDU_error("Required parameter '${ARG_NAME}' is not specified.")
    endif()

    # Если параметр не обязателен и не предоставлен, дальнейшая проверка не нужна
    if(NOT ARG_VALUE)
        return()
    endif()

    # Проверка по типу
    if(ARG_TYPE STREQUAL "STRING")
        # Любая непустая строка подходит
    elseif(ARG_TYPE STREQUAL "LIST")
        # Проверяем, что значение является списком
        list(LENGTH ARG_VALUE len)
        if(len LESS 1 AND NOT "${ARG_VALUE}" STREQUAL "")
            CDU_warning("Parameter '${ARG_NAME}' must be a list, but looks like a string: '${ARG_VALUE}'.")
        endif()
    elseif(ARG_TYPE STREQUAL "BOOL")
        if(NOT (ARG_VALUE STREQUAL "ON" OR ARG_VALUE STREQUAL "OFF" OR
                ARG_VALUE STREQUAL "TRUE" OR ARG_VALUE STREQUAL "FALSE" OR
                ARG_VALUE STREQUAL "1" OR ARG_VALUE STREQUAL "0"))
            CDU_error("Parameter '${ARG_NAME}' must be a bool (ON/OFF, TRUE/FALSE, 1/0), but specified: '${ARG_VALUE}'.")
        endif()
    elseif(ARG_TYPE STREQUAL "PATH")
        # Проверяем, существует ли путь
        if(NOT EXISTS "${ARG_VALUE}")
            CDU_warning("Path '${ARG_VALUE}' for parameter '${ARG_NAME}' not exist.")
        endif()
    elseif(ARG_TYPE STREQUAL "TARGET")
        if(NOT TARGET "${ARG_VALUE}")
            CDU_error("Parameter '${ARG_NAME}' ref to unknown target: '${ARG_VALUE}'.")
        endif()
    else()
        CDU_warning("Unknown type '${ARG_TYPE}' for validation parameter '${ARG_NAME}'.")
    endif()

    CDU_debug("Parameter '${ARG_NAME}' successfuly validated (Type: ${ARG_TYPE}, Value: '${ARG_VALUE}').")
endfunction()

# ========================================================================================
# Профилирование
# ========================================================================================

# Начинает профилирование операции.
function(CDU_profile_start OPERATION)
    if(CDU_DEBUG_MODE)
        string(TIMESTAMP start_time "%s")
        set_property(GLOBAL PROPERTY "PROFILE_${OPERATION}_START" "${start_time}")
        CDU_debug("Starting operation profiling: ${OPERATION}")
    endif()
endfunction()

# Завершает профилирование и выводит результат.
function(CDU_profile_end OPERATION)
    if(CDU_DEBUG_MODE)
        get_property(start_time GLOBAL PROPERTY "PROFILE_${OPERATION}_START")
        if(start_time)
            string(TIMESTAMP end_time "%s")
            math(EXPR duration "${end_time} - ${start_time}")
            CDU_info("Operation '${OPERATION}' completed with ${duration} sec.")
            set_property(GLOBAL PROPERTY "PROFILE_${OPERATION}_START" "") # Сброс
        else()
            CDU_warning("Not found start time for the profilig operation: ${OPERATION}")
        endif()
    endif()
endfunction()

# ========================================================================================
# Проверка версии CMake
# ========================================================================================

# Проверяет минимально необходимую версию CMake.
function(CDU_check_cmake_version MINIMUM)
    if(CMAKE_VERSION VERSION_LESS "${MINIMUM}")
        CDU_error("Current cmake version ${CMAKE_VERSION} too old. Minimum version required ${MINIMUM}.")
    endif()
    CDU_debug("CMake version check is completed: ${CMAKE_VERSION} >= ${MINIMUM}.")
endfunction()

CDU_debug("Module 'utils' is loaded.")
