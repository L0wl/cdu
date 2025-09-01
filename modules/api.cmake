# ========================================================================================
# CMake Deploy Utilities (CDU) - Публичный API
#
# Этот модуль предоставляет удобные функции-обертки для объявления таргетов
# в CMake-проекте. Это основной интерфейс, который должен использоваться
# в файлах CMakeLists.txt.
# ========================================================================================

# Защита от повторного включения
if(CDU_API_MODULE_LOADED)
    return()
endif()
set(CDU_API_MODULE_LOADED TRUE)

# ========================================================================================
# Функции для объявления таргетов
# ========================================================================================

##
# @brief Объявляет исполняемый файл приложения.
#
# Создает исполняемый файл, настраивает для него стандартные свойства,
# иконку, версию (для Windows) и готовит его к развертыванию (деплою).
#
# @param name Имя таргета.
#
# @arg ALIAS Псевдоним (alias) для таргета.
# @arg SOURCES Список исходных файлов.
# @arg PLUGINS Список плагинов, которые должны быть задеплоены вместе с приложением.
# @arg COMPILE_DEFINITIONS Список макроопределений компилятора.
# @arg PUBLIC Список публичных зависимостей (библиотек).
# @arg PRIVATE Список приватных зависимостей (библиотек).
#
# @example
# declare_application(my_app
#     SOURCES src/main.cpp
#     PLUGINS my_plugin_a my_plugin_b
#     PUBLIC Qt6::Widgets
# )
function(declare_application name)
    cmake_parse_arguments(ARG "" "ALIAS;PCH" "SOURCES;PACKAGES;PLUGINS;COMPILE_DEFINITIONS;PUBLIC;PRIVATE;PCH_FILES" ${ARGN})

    # Внутренний вызов для создания исполняемого файла
    _CDU_declare_target(${name}
        TYPE EXECUTABLE
        ALIAS ${ARG_ALIAS}
        PCH ${ARG_PCH}
        PCH_FILES ${ARG_PCH_FILES}
        SOURCES ${ARG_SOURCES}
        PUBLIC ${ARG_PUBLIC}
        PRIVATE ${ARG_PRIVATE}
        COMPILE_DEFINITIONS ${ARG_COMPILE_DEFINITIONS}
    )

if(NOT TARGET ${name})
    return()
endif()

# Устанавливаем свойства, специфичные для приложения
set_target_properties(${name} PROPERTIES
    INSTALL_DIR "apps/${name}" # Директория установки
    TARGET_PLUGINS "${ARG_PLUGINS}" # Список связанных плагинов
    TARGET_PACKAGES "${ARG_PACKAGES}" # Список связанных пакетов
)

# Настраиваем деплой
_CDU_declare_deploy(${name})

CDU_info("Definition of application: ${name}")
endfunction()

##
# @brief Объявляет консольную утилиту.
#
# Аналогична `declare_application`, но устанавливается в директорию `tools/`
# вместо `apps/`.
#
# @param name Имя таргета.
# (Параметры аналогичны declare_application)
function(declare_utility name)
    cmake_parse_arguments(ARG "" "ALIAS;PCH" "SOURCES;PACKAGES;PLUGINS;COMPILE_DEFINITIONS;PUBLIC;PRIVATE;PCH_FILES" ${ARGN})

    _CDU_declare_target(${name}
        TYPE EXECUTABLE
        ALIAS ${ARG_ALIAS}
        PCH ${ARG_PCH}
        PCH_FILES ${ARG_PCH_FILES}
        SOURCES ${ARG_SOURCES}
        PUBLIC ${ARG_PUBLIC}
        PRIVATE ${ARG_PRIVATE}
        COMPILE_DEFINITIONS ${ARG_COMPILE_DEFINITIONS}
    )

if(NOT TARGET ${name})
    return()
endif()

set_target_properties(${name} PROPERTIES
    INSTALL_DIR "tools/${name}" # Директория установки
    TARGET_PLUGINS "${ARG_PLUGINS}" # Список связанных плагинов
    TARGET_PACKAGES "${ARG_PACKAGES}" # Список связанных пакетов
)

_CDU_declare_deploy(${name})

CDU_info("Definition of utility: ${name}")
endfunction()

##
# @brief Объявляет пакет с данными.
#
# Пакет - это логическая группа файлов (конфиги, сценарии, и т.д.),
# которая может быть установлена вместе с приложением.
#
# @param name Имя таргета пакета.
#
# @arg ALIAS Псевдоним (alias) для таргета.
# @arg FILES Список файлов, входящих в пакет (пути относительны CMakeLists.txt).
# @arg DESTINATION Относительный путь внутри директории приложения, куда будут скопированы файлы.
#
# @example
# declare_package(my_configs
#     FILES config.json defaults.ini
#     DESTINATION "config"
# )
function(declare_package name)
    cmake_parse_arguments(ARG "" "ALIAS;DESTINATION" "FILES" ${ARGN})

    if(NOT ARG_FILES)
        CDU_warning("declare_package(${name}): No files specified via FILES. Package will be empty.")
    endif()

    if(NOT ARG_DESTINATION)
        CDU_error("declare_package(${name}): DESTINATION is a required argument.")
    endif()

    # Создаем INTERFACE таргет
    add_library(${name}_package INTERFACE)
    if(ARG_ALIAS)
        add_library(${ARG_ALIAS} ALIAS ${name}_package)
    endif()

    # Преобразуем относительные пути файлов в абсолютные
    set(absolute_files "")
    foreach(file IN LISTS ARG_FILES)
        if(IS_ABSOLUTE "${file}")
            list(APPEND absolute_files "${file}")
        else()
            list(APPEND absolute_files "${CMAKE_CURRENT_SOURCE_DIR}/${file}")
        endif()
    endforeach()

    target_sources(${name}_package INTERFACE
        ${ARG_FILES}
    )

    # Сохраняем информацию в свойствах таргета
    set_target_properties(${name}_package PROPERTIES
        IS_PACKAGE TRUE
        PACKAGE_FILES "${absolute_files}"
        PACKAGE_DESTINATION "${ARG_DESTINATION}"
    )

    CDU_info("Definition of package: ${name}")
endfunction()

##
# @brief Объявляет библиотеку.
#
# Создает библиотеку указанного типа (SHARED, STATIC или INTERFACE).
#
# @param name Имя таргета.
# @param type Тип библиотеки: SHARED, STATIC или INTERFACE.
#
# @arg ALIAS Псевдоним (alias) для таргета.
# @arg SOURCES Список исходных файлов (не для INTERFACE).
# @arg INCLUDE_DIRS Публичные директории с заголовочными файлами.
# @arg COMPILE_FEATURES Требуемые возможности компилятора (например, cxx_std_17).
# @arg COMPILE_DEFINITIONS Список макроопределений.
# @arg PUBLIC Список публичных зависимостей.
# @arg PRIVATE Список приватных зависимостей.
#
# @example
# declare_library(my_lib SHARED
#     SOURCES src/my_lib.cpp
#     PUBLIC Qt6::Core
# )
function(declare_library name type)
    cmake_parse_arguments(ARG "" "ALIAS;PCH" "SOURCES;INCLUDE_DIRS;COMPILE_FEATURES;COMPILE_DEFINITIONS;PRIVATE;PUBLIC;PCH_FILES" ${ARGN})

    if(NOT (type STREQUAL "SHARED" OR type STREQUAL "STATIC" OR type STREQUAL "INTERFACE"))
        CDU_error("declare_library(${name}): unknown type '${type}'. Use SHARED, STATIC or INTERFACE.")
    endif()

    _CDU_declare_target(${name}
        TYPE "${type}_LIBRARY"
        ALIAS ${ARG_ALIAS}
        PCH ${ARG_PCH}
        PCH_FILES ${ARG_PCH_FILES}
        SOURCES ${ARG_SOURCES}
        PUBLIC ${ARG_PUBLIC}
        PRIVATE ${ARG_PRIVATE}
        COMPILE_DEFINITIONS ${ARG_COMPILE_DEFINITIONS}
        COMPILE_FEATURES ${ARG_COMPILE_FEATURES}
        INCLUDE_DIRS ${ARG_INCLUDE_DIRS}
    )

CDU_info("Definition of library: ${name} (type: ${type})")
endfunction()

##
# @brief Объявляет плагин.
#
# Плагин - это особый вид разделяемой библиотеки (SHARED), который
# устанавливается в отдельную директорию `plugins/<category>`.
#
# @param name Имя таргета.
# @param category Категория плагина (используется для создания поддиректории).
#
# @arg ALIAS Псевдоним (alias) для таргета.
# @arg SOURCES Список исходных файлов.
# @arg PUBLIC Список публичных зависимостей.
# @arg PRIVATE Список приватных зависимостей.
# @arg COMPILE_DEFINITIONS Список макроопределений.
#
# @example
# declare_plugin(my_plugin "scanners"
#     SOURCES src/my_plugin.cpp
#     PUBLIC my_lib
# )
function(declare_plugin name category)
    cmake_parse_arguments(ARG "" "ALIAS;PCH" "SOURCES;PUBLIC;PRIVATE;COMPILE_DEFINITIONS;PCH_FILES" ${ARGN})

    if(NOT name OR NOT category)
        CDU_error("Usage: declare_plugin(<name> <category> ...)")
    endif()

    # Плагин - это всегда разделяемая библиотека
    declare_library(${name} SHARED
        ALIAS ${ARG_ALIAS}
        PCH ${ARG_PCH}
        PCH_FILES ${ARG_PCH_FILES}
        SOURCES ${ARG_SOURCES}
        PUBLIC ${ARG_PUBLIC}
        PRIVATE ${ARG_PRIVATE}
        COMPILE_DEFINITIONS ${ARG_COMPILE_DEFINITIONS}
    )

# Устанавливаем свойства, специфичные для плагина
if(TARGET ${name})
    set_target_properties(${name} PROPERTIES
        PREFIX "" # Убираем префикс 'lib'
        IS_PLUGIN TRUE # Маркер, что это плагин
        PLUGIN_CATEGORY "${category}" # Категория для сортировки
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins/${category}"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins/${category}"
    )
endif()

CDU_info("Definition of plugin: ${name} (category: ${category})")
endfunction()

CDU_debug("Module 'CDU_api' is loaded.")
