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
# @brief (Внутренняя) Возвращает реальное имя таргета, разрешая алиасы.
#
# Если переданное имя - это алиас, функция вернет имя цели, на которую
# он указывает. Если это уже реальный таргет, вернет его же.
#
# @param out_var Переменная для сохранения результата.
# @param in_name Имя (возможно, алиас) для проверки.
#
function(_CDU_get_real_target_name out_var in_name)
    set(real_name ${in_name})
    if(TARGET ${in_name})
        get_target_property(aliased_target ${in_name} ALIASED_TARGET)
        if(aliased_target)
            set(real_name ${aliased_target})
        else()
            get_target_property(mapped_target ${in_name} CDU_REAL_TARGET)
            if(mapped_target AND NOT mapped_target STREQUAL "NOTFOUND")
                set(real_name ${mapped_target})
            endif()
        endif()
    endif()
    set(${out_var} ${real_name} PARENT_SCOPE)
endfunction()

##
# @brief (Внутренняя) Возвращает пространство имён для авто-создаваемых таргетов.
#
# Значение берётся из переменной CDU_TARGET_NAMESPACE. Пустая строка означает,
# что генерация пространств имён отключена.
#
# @param out_var Переменная для сохранения результата.
#
function(_CDU_get_target_namespace out_var)
    if(CDU_TARGET_NAMESPACE)
        set(namespace "${CDU_TARGET_NAMESPACE}")
    else()
        set(namespace "")
    endif()
    set(${out_var} "${namespace}" PARENT_SCOPE)
endfunction()

##
# @brief (Внутренняя) Регистрирует таргет в пространстве имён проекта.
#
# Создаёт глобальную INTERFACE-цель вида `<namespace>::<display_name>`,
# которая транзитивно ссылается на реальный таргет. Это позволяет ссылаться
# на библиотеки проекта через единое пространство имён без использования ALIAS.
#
# @param real_target Имя реального таргета.
# @arg DISPLAY_NAME Имя, используемое в пространстве имён (по умолчанию совпадает с real_target).
#
function(_CDU_register_namespaced_target real_target)
    cmake_parse_arguments(ARG "" "DISPLAY_NAME" "" ${ARGN})

    if(NOT TARGET ${real_target})
        return()
    endif()

    _CDU_get_target_namespace(namespace)
    if(NOT namespace)
        return()
    endif()

    if(NOT ARG_DISPLAY_NAME)
        set(ARG_DISPLAY_NAME ${real_target})
    endif()

    get_target_property(target_type ${real_target} TYPE)
    if(target_type STREQUAL "EXECUTABLE")
        return()
    endif()

    set(namespaced_target "${namespace}::${ARG_DISPLAY_NAME}")

    if(TARGET ${namespaced_target})
        get_target_property(_mapped_target ${namespaced_target} CDU_REAL_TARGET)
        if(_mapped_target AND NOT _mapped_target STREQUAL "${real_target}")
            CDU_error("Namespace target '${namespaced_target}' is already mapped to '${_mapped_target}'.")
        endif()
    else()
        add_library(${namespaced_target} INTERFACE IMPORTED GLOBAL)
    endif()

    set_target_properties(${namespaced_target} PROPERTIES
        CDU_REAL_TARGET ${real_target}
    )
    set_property(TARGET ${namespaced_target} PROPERTY INTERFACE_LINK_LIBRARIES ${real_target})

    set_target_properties(${real_target} PROPERTIES EXPORT_NAME "${ARG_DISPLAY_NAME}")

    get_property(_registered GLOBAL PROPERTY CDU_NAMESPACED_TARGETS)
    if(NOT _registered)
        set(_registered "")
    endif()

    set(_pair "${ARG_DISPLAY_NAME}|${real_target}")
    list(FIND _registered "${_pair}" _idx)
    if(_idx EQUAL -1)
        list(APPEND _registered "${_pair}")
        set_property(GLOBAL PROPERTY CDU_NAMESPACED_TARGETS "${_registered}")
    endif()

    get_property(_deferred GLOBAL PROPERTY CDU_NAMESPACED_EXPORT_DEFERRED)
    if(NOT _deferred)
        set_property(GLOBAL PROPERTY CDU_NAMESPACED_EXPORT_DEFERRED TRUE)
        cmake_language(DEFER CALL _CDU_finalize_namespace_exports)
    endif()

    CDU_debug("Registered namespace target '${namespaced_target}' for '${real_target}'.")
endfunction()

function(_CDU_finalize_namespace_exports)
    _CDU_get_target_namespace(_namespace)
    if(NOT _namespace)
        return()
    endif()

    get_property(_pairs GLOBAL PROPERTY CDU_NAMESPACED_TARGETS)
    if(NOT _pairs)
        return()
    endif()

    include(GNUInstallDirs)
    include(CMakePackageConfigHelpers)

    set(_export_set "${_namespace}Targets")
    set(_cdu_binary_dir "${CMAKE_BINARY_DIR}/cdu")
    file(MAKE_DIRECTORY "${_cdu_binary_dir}")

    set(_targets_to_export "")
    foreach(_entry IN LISTS _pairs)
        string(REPLACE "|" ";" _parts "${_entry}")
        list(GET _parts 0 _display)
        list(GET _parts 1 _target)
        if(NOT TARGET "${_target}")
            continue()
        endif()
        get_target_property(_type "${_target}" TYPE)
        if(_type STREQUAL "EXECUTABLE")
            continue()
        endif()

        list(APPEND _targets_to_export "${_target}")

        if(_type STREQUAL "INTERFACE_LIBRARY")
            install(TARGETS "${_target}" EXPORT "${_export_set}")
        else()
            install(TARGETS "${_target}"
                EXPORT "${_export_set}"
                ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
                LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
                RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
                INCLUDES DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
            )
        endif()
    endforeach()

    list(REMOVE_DUPLICATES _targets_to_export)
    if(NOT _targets_to_export)
        return()
    endif()

    set(_export_build "${_cdu_binary_dir}/${_export_set}.cmake")
    export(EXPORT "${_export_set}"
        FILE "${_export_build}"
        NAMESPACE "${_namespace}::"
    )

    set(_config_template "${CDU_MODULES_DIR}/templates/package-config.cmake.in")
    if(NOT EXISTS "${_config_template}")
        CDU_warning("Package config template not found: ${_config_template}")
        return()
    endif()

    set(_config_build "${_cdu_binary_dir}/${_namespace}Config.cmake")
    set(_version_build "${_cdu_binary_dir}/${_namespace}ConfigVersion.cmake")

    set(_install_dir "${CMAKE_INSTALL_LIBDIR}/cmake/${_namespace}")

    set(PACKAGE_TARGETS_FILE "${_export_set}.cmake")
    configure_package_config_file("${_config_template}" "${_config_build}"
        INSTALL_DESTINATION "${_install_dir}"
    )

    set(_package_version "0.0.0")
    if(CMAKE_PROJECT_VERSION)
        set(_package_version "${CMAKE_PROJECT_VERSION}")
    elseif(PROJECT_VERSION)
        set(_package_version "${PROJECT_VERSION}")
    endif()

    write_basic_package_version_file("${_version_build}"
        VERSION "${_package_version}"
        COMPATIBILITY SameMajorVersion
    )

    install(EXPORT "${_export_set}"
        FILE "${_export_set}.cmake"
        NAMESPACE "${_namespace}::"
        DESTINATION "${_install_dir}"
    )

    install(FILES
        "${_config_build}"
        "${_version_build}"
        DESTINATION "${_install_dir}"
    )
endfunction()

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
    set(cdu_res_${target_name} "${CMAKE_CURRENT_BINARY_DIR}/cdu_res_${target_name}.rc")
    configure_file(${CDU_RC_TEMPLATE} ${cdu_res_${target_name}} @ONLY)
    target_sources(${target_name} PRIVATE "${cdu_res_${target_name}}")

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
    elseif(ARG_TYPE STREQUAL "MODULE_LIBRARY")
        add_library(${name} MODULE ${ARG_SOURCES})
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
        set_target_properties(${name} PROPERTIES
            OUTPUT_NAME "${name}"
            RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
            LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
            ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        )

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

        set(_cdu_public_includes ${ARG_INCLUDE_DIRS})
        list(APPEND _cdu_public_includes
            "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
            "$<INSTALL_INTERFACE:include>"
        )
        target_include_directories(${name} PUBLIC ${_cdu_public_includes})

        # Конфигурация версии для Windows
        if(WIN32)
            _CDU_configure_windows_version_info(${name})
        endif()
    endif()

    # --- Свойства базового RPATH для бинарников и библиотек ---
    if(UNIX AND NOT APPLE AND (ARG_TYPE STREQUAL "EXECUTABLE" OR ARG_TYPE STREQUAL "SHARED_LIBRARY" OR ARG_TYPE STREQUAL "MODULE_LIBRARY"))
        set_target_properties(${name} PROPERTIES
            BUILD_RPATH "\$ORIGIN"
            INSTALL_RPATH "\$ORIGIN"
            INSTALL_RPATH_USE_LINK_PATH TRUE
            BUILD_WITH_INSTALL_RPATH TRUE
        )
    elseif(APPLE AND (ARG_TYPE STREQUAL "EXECUTABLE" OR ARG_TYPE STREQUAL "SHARED_LIBRARY" OR ARG_TYPE STREQUAL "MODULE_LIBRARY"))
        set_target_properties(${name} PROPERTIES
            BUILD_RPATH "@loader_path"
            INSTALL_RPATH "@loader_path"
            INSTALL_RPATH_USE_LINK_PATH TRUE
            BUILD_WITH_INSTALL_RPATH TRUE
        )
    endif()

    # --- Свойства для INTERFACE библиотек ---
    if(ARG_TYPE STREQUAL "INTERFACE_LIBRARY")
        if(ARG_INCLUDE_DIRS OR EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/include")
            set(_cdu_interface_includes ${ARG_INCLUDE_DIRS})
            list(APPEND _cdu_interface_includes
                "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
                "$<INSTALL_INTERFACE:include>"
            )
            target_include_directories(${name} INTERFACE ${_cdu_interface_includes})
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

    _CDU_register_namespaced_target(${name})
endfunction()

CDU_debug("Module 'CDU_target' is loaded.")
