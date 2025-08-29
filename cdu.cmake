# ========================================================================================
# CMake Deploy Utilities (CDU) - Единая точка входа
#
# Это главный и единственный файл, который необходимо подключить в корневом
# CMakeLists.txt вашего проекта: `include(cdu)`.
#
# Он загружает все необходимые компоненты и предоставляет централизованные настройки.
# ========================================================================================

# Защита от повторного включения
if(CDU_LOADED)
    return()
endif()
set(CDU_LOADED TRUE)

# Определяем базовую директорию, где лежит этот файл
get_filename_component(CDU_BASE_DIR "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)
# Определяем директорию с модулями (cdu/modules)
set(CDU_MODULES_DIR "${CDU_BASE_DIR}/modules")

# ========================================================================================
# ========================================================================================
#
#     ПОЛЬЗОВАТЕЛЬСКАЯ КОНФИГУРАЦИЯ (User Configuration)
#     Все основные настройки CDU производятся в этом блоке.
#     Вам не нужно редактировать файлы в директории /modules.
#
#     Переконфигурация проекта обязательна после редактирования!
#
# ========================================================================================
# ========================================================================================

# @brief Уровень логирования: ERROR, WARNING, INFO, DEBUG
if(NOT CDU_LOG_LEVEL)
    set(CDU_LOG_LEVEL "INFO" CACHE STRING "Уровень логирования: DEBUG, INFO, WARNING, ERROR")
endif()

# @brief Включить режим отладки для вывода детальной информации.
if(NOT CDU_DEBUG_MODE)
    set(CDU_DEBUG_MODE OFF CACHE BOOL "Включить режим отладки для детального логирования")
endif()

# @brief Дополнительные директории для поиска зависимостей (через точку с запятой).
# @example set(CDU_DEPLOY_ADDITIONAL_DIRS "C:/MyLibs/bin")
if(NOT CDU_DEPLOY_ADDITIONAL_DIRS)
    set(CDU_DEPLOY_ADDITIONAL_DIRS "" CACHE STRING "Дополнительные директории для поиска зависимостей.")
endif()

# @brief Дополнительные регулярные выражения для исключения системных библиотек.
if(NOT CDU_DEPLOY_EXTRA_POST_EXCLUDE_REGEXES)
    set(CDU_DEPLOY_EXTRA_POST_EXCLUDE_REGEXES "" CACHE STRING "Дополнительные regex-ы для исключения библиотек при деплое.")
endif()

# @brief Включать ли директорию компилятора в поиск
option(CDU_DEPLOY_INCLUDE_TOOLCHAIN_BIN "Добавлять путь к компилятору в поиск зависимостей" OFF)

# @brief Путь к файлу предкомпилированного заголовка (Будет подключён к каждому таргету)
# @note Оставьте пустым, чтобы отключить PCH.
if(NOT CDU_PCH_FILE)
    set(CDU_PCH_FILE "" CACHE STRING "Путь к файлу предкомпилированного заголовка (PCH).")
endif()

# @brief Статус включения предкомпилированного заголовка, если не указано для цели
# @example При OFF - стандартный заголовок не будет включён в цель, если не задан
# @example При ON - стандартный заголовок будет включён в цель, если стандартный заголовок доступен
option(CDU_PCH_UNSPECIFIED_DEFAULT_STATE "Статус включения заголовка (Если не указано для цели)" ON)

# @brief Путь к шаблону ресурсного файла (.rc) для Windows.
# @note Оставьте пустым, чтобы отключить авто-генерацию версии.
if(NOT CDU_RC_TEMPLATE)
    set(CDU_RC_TEMPLATE "" CACHE STRING "Путь к шаблону ресурсного файла (.rc) для Windows.")
endif()

# ========================================================================================
# Конец пользовательской конфигурации
# ========================================================================================

# Внутренние переменные
set(CDU_DECLARED_TARGETS "" CACHE INTERNAL "Список всех задекларированных таргетов")

# ========================================================================================
# Загрузка модулей
# ========================================================================================

# Сначала подключаем базовые утилиты (логирование, валидация и т.д.)
include("${CDU_MODULES_DIR}/utils.cmake")

CDU_info("CDU build system is loading. Path to modules: ${CDU_MODULES_DIR}")

# --- Логирование текущих настроек ---
CDU_info("--- CDU Configuration ---")
CDU_info("Log level:\t\t\t${CDU_LOG_LEVEL}")
CDU_info("Debug mode:\t\t\t${CDU_DEBUG_MODE}")
CDU_info("PCH file:\t\t\t${CDU_PCH_FILE}")
CDU_info("RC template:\t\t\t${CDU_RC_TEMPLATE}")
CDU_info("Deploy Additional dirs:\t\t${CDU_DEPLOY_ADDITIONAL_DIRS}")
CDU_info("Deploy extra exclude regexes:\t${CDU_DEPLOY_EXTRA_POST_EXCLUDE_REGEXES}")
CDU_info("Deploy include toolchain bin:\t${CDU_DEPLOY_INCLUDE_TOOLCHAIN_BIN}")
CDU_info("-------------------------")

# Проверка минимальной версии CMake
CDU_check_cmake_version("3.21")

# Внутренняя функция для загрузки модулей
function(_CDU_load_module name)
    set(module_path "${CDU_MODULES_DIR}/${name}.cmake")
    if(EXISTS "${module_path}")
        CDU_debug("Loading module: ${name}")
        include("${module_path}")
    else()
        CDU_error("Critical buildsystem module not found: ${module_path}")
    endif()
endfunction()

# Загружаем все составные части системы сборки
_CDU_load_module(target)
_CDU_load_module(deploy)
_CDU_load_module(api)
_CDU_load_module(include_projects)

CDU_info("CDU build system successfully loaded")
