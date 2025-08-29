# ========================================================================================
# CMake Deploy Utilities (CDU) - Модуль создания таргетов
#
# Внутренний модуль, отвечающий за создание и конфигурацию таргетов
# (исполняемых файлов, библиотек). Этот модуль не предназначен для прямого
# использования в CMakeLists.txt конечного пользователя.
# ========================================================================================

# Защита от повторного включения
if(CDU_TARGET_MODULE_LOADED)
    return()
endif()
set(CDU_TARGET_MODULE_LOADED TRUE)

# ========================================================================================
# Внутренние вспомогательные функции
# ========================================================================================

##
# @brief (Внутренняя) Внедряет информацию о версии Windows в бинарный файл.
#
# Добавляет статический .rc файл к исходникам таргета и передает в него
# информацию о версии и имени таргета через макроопределения компилятора.
#
# @param target_name Имя целевого таргета.
#
function(_CDU_configure_windows_version_info target_name)
    get_target_property(target_type ${target_name} TYPE)
    if(NOT (target_type STREQUAL "EXECUTABLE" OR target_type STREQUAL "SHARED_LIBRARY"))
        return()
    endif()

    # Проверяем, что RC-файл существует
    if(NOT (CDU_RC_TEMPLATE AND EXISTS "${CDU_RC_TEMPLATE}"))
        CDU_debug("Metadata template not specified: CDU_RC_TEMPLATE is not set or file not found.")
        return()
    endif()

    # Значения по умолчанию
    set(version_major ${PROJECT_VERSION_MAJOR})
    set(version_minor ${PROJECT_VERSION_MINOR})
    set(version_patch ${PROJECT_VERSION_PATCH})
    set(version_build ${PROJECT_VERSION_TWEAK})

    if(NOT version_major)
        set(version_major 0)
    endif()
    if(NOT version_minor)
        set(version_minor 0)
    endif()
    if(NOT version_patch)
        set(version_patch 0)
    endif()
    if(NOT version_build)
        set(version_build 0)
    endif()

    set(description ${PROJECT_DESCRIPTION})
    if(NOT description)
        set(description "N/A")
    endif()

        # Определение типа файла и имени для .rc
        if(target_type STREQUAL "EXECUTABLE")
            set(rc_file_type "VFT_APP")
            set(original_filename "${target_name}.exe")
        else()
            set(rc_file_type "VFT_DLL")
            set(original_filename "${target_name}.dll")
        endif()

        # Добавляем RC-файл к исходникам
        target_sources(${target_name} PRIVATE "${CDU_RC_TEMPLATE}")

        # Передаем данные в RC-файл через макросы
        target_compile_definitions(${target_name} PRIVATE
            CDU_VERSION_MAJOR=${version_major}
            CDU_VERSION_MINOR=${version_minor}
            CDU_VERSION_PATCH=${version_patch}
            CDU_VERSION_BUILD=${version_build}
            CDU_FILE_DESCRIPTION_STR="${description}"
            CDU_INTERNAL_NAME_STR="${target_name}"
            CDU_ORIGINAL_FILENAME_STR="${original_filename}"
            CDU_RC_FILE_TYPE ${rc_file_type}
        )

    CDU_debug("Windows metadata configured for target '${target_name}' via compile definitions.")
endfunction()


# ========================================================================================
# Основная функция создания таргета (внутренняя)
# ========================================================================================

##
# @brief (Внутренняя) Единая функция для создания и базовой настройки таргетов.
#
# Эта функция является сердцем системы. Она вызывается из публичных функций
# (declare_application, declare_library) и выполняет следующие действия:
#   1. Создает таргет нужного типа (add_executable/add_library).
#   2. Создает псевдоним (alias), если требуется.
#   3. Настраивает PCH (Precompiled Headers).
#   4. Добавляет стандартные пути для include-директорий.
#   5. Управляет опциями компиляции и линковки.
#   6. Регистрирует таргет в глобальном списке CDU_DECLARED_TARGETS.
#
# @param name Имя таргета.
# @arg TYPE Тип таргета (EXECUTABLE, SHARED_LIBRARY, etc.).
# @arg ... Остальные аргументы передаются из публичных функций.
#
function(_CDU_declare_target name)
    cmake_parse_arguments(ARG "" "TYPE;ALIAS;PCH" "SOURCES;INCLUDE_DIRS;COMPILE_FEATURES;COMPILE_DEFINITIONS;PRIVATE;PUBLIC;PCH_FILES" ${ARGN})

    # Создание таргета в зависимости от типа
    if(ARG_TYPE STREQUAL "EXECUTABLE")
        add_executable(${name} ${ARG_SOURCES})
    elseif(ARG_TYPE STREQUAL "STATIC_LIBRARY")
        add_library(${name} STATIC ${ARG_SOURCES})
    elseif(ARG_TYPE STREQUAL "SHARED_LIBRARY")
        add_library(${name} SHARED ${ARG_SOURCES})
    elseif(ARG_TYPE STREQUAL "INTERFACE_LIBRARY")
        add_library(${name} INTERFACE)
    else()
        CDU_error("Unknown target type '${ARG_TYPE}' for '${name}'.")
    endif()

    # Создание псевдонима (alias) для таргета, если указан
    if(ARG_ALIAS)
        add_library(${ARG_ALIAS} ALIAS ${name})
        CDU_debug("Created alias '${ARG_ALIAS}' for target '${name}'.")
    endif()

    # --- Общие свойства для всех "сборных" таргетов ---
    if(NOT ARG_TYPE STREQUAL "INTERFACE_LIBRARY")
        set_target_properties(${name} PROPERTIES OUTPUT_NAME "${name}")

        if(NOT ARG_PCH)
            set(ARG_PCH ${CDU_PCH_UNSPECIFIED_DEFAULT_STATE})
        endif()

        # Подключение предкомпилированных заголовков (PCH)
        set(PCH_FILES)
        if(ARG_PCH)
            if(CDU_PCH_FILE AND EXISTS "${CDU_PCH_FILE}")
                list(APPEND PCH_FILES ${CDU_PCH_FILE})
            endif()
        endif()

        list(LENGTH ARG_PCH_FILES custom_pch_length)
        if(ARG_PCH_FILES AND (custom_pch_length GREATER 0))
            foreach(PCH_FILE IN LISTS ARG_PCH_FILES)
                if(EXISTS "${PCH_FILE}")
                    list(APPEND PCH_FILES ${PCH_FILE})
                endif()
            endforeach()
        endif()

        list(LENGTH PCH_FILES target_pchs_length)
        if(PCH_FILES AND target_pchs_length GREATER 0)
            target_precompile_headers(${name} PRIVATE "${PCH_FILES}")
        endif()


        # Автоматическое добавление директорий 'src' и 'include'
        target_include_directories(${name} PRIVATE
            "${CMAKE_CURRENT_SOURCE_DIR}/src"
            "${CMAKE_CURRENT_SOURCE_DIR}/include"
        )

        # Добавление публичных include-директорий
        target_include_directories(${name} PUBLIC
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
            ${ARG_INCLUDE_DIRS}
        )

        # Конфигурация версии для Windows
        if(WIN32)
            _CDU_configure_windows_version_info(${name})
        endif()
    endif()

    # --- Свойства для INTERFACE библиотек ---
    if(ARG_TYPE STREQUAL "INTERFACE_LIBRARY")
        if(ARG_INCLUDE_DIRS OR EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/include")
            target_include_directories(${name} INTERFACE
                "${CMAKE_CURRENT_SOURCE_DIR}/include"
                ${ARG_INCLUDE_DIRS}
            )
        endif()
    endif()

    # --- Опции компиляции и определения ---
    if(ARG_COMPILE_FEATURES)
        target_compile_features(${name} PUBLIC ${ARG_COMPILE_FEATURES})
    endif()

    if(NOT ARG_TYPE STREQUAL "INTERFACE_LIBRARY")
        target_compile_definitions(${name} PRIVATE ${ARG_COMPILE_DEFINITIONS}
            TARGET_VERSION="${${name}_VERSION}"
            TARGET_NAME="${name}"
        )
    else()
        target_compile_definitions(${name} INTERFACE ${ARG_COMPILE_DEFINITIONS})
    endif()

    # --- Линковка с другими библиотеками ---
    if(ARG_PRIVATE)
        target_link_libraries(${name} PRIVATE ${ARG_PRIVATE})
    endif()
    if(ARG_PUBLIC)
        target_link_libraries(${name} PUBLIC ${ARG_PUBLIC})
    endif()

    # Регистрация таргета в глобальном списке для последующей обработки (например, деплоя)
    list(APPEND CDU_DECLARED_TARGETS ${name})
    set(CDU_DECLARED_TARGETS ${CDU_DECLARED_TARGETS} CACHE INTERNAL "Список всех таргетов, объявленных через CDU")

    CDU_debug("Internal target '${name}' with type '${ARG_TYPE}' successfuly created.")
endfunction()

CDU_debug("Module 'CDU_target' is loaded.")
