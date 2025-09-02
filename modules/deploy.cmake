# ========================================================================================
# CMake Deploy Utilities (CDU) - Модуль деплоя
#
# Внутренний модуль, отвечающий за установку (install) и сборку бандла
# для исполняемых файлов, включая их зависимости (DLL) и плагины.
# Использует стандартный модуль CMake 'BundleUtilities'.
# ========================================================================================

# Защита от повторного включения
if(CDU_DEPLOY_MODULE_LOADED)
    return()
endif()
set(CDU_DEPLOY_MODULE_LOADED TRUE)

include(GNUInstallDirs)

##
# @brief (Внутренняя) Собирает список директорий для поиска рантайм-зависимостей.
#
# Функция анализирует таргет и его зависимости (включая плагины) и формирует
# список путей, где `file(GET_RUNTIME_DEPENDENCIES)` будет искать библиотеки.
#
# @param out_var Имя переменной, в которую будет записан список директорий.
# @param main_target Основной таргет (приложение), для которого ищутся зависимости.
#
function(_CDU_collect_runtime_dirs out_var main_target)
    set(_dirs "")

    # Корень сборки — там часто лежат наши артефакты
    list(APPEND _dirs "${CMAKE_BINARY_DIR}")

    # Каталоги всех SHARED библиотек и плагинов, объявленных через CDU
    foreach(tgt IN LISTS CDU_DECLARED_TARGETS)
        if(TARGET "${tgt}")
            get_target_property(_type ${tgt} TYPE)
            get_target_property(_is_plugin ${tgt} IS_PLUGIN)
            if(_type STREQUAL "SHARED_LIBRARY" OR _is_plugin)
                list(APPEND _dirs "$<TARGET_FILE_DIR:${tgt}>")
            endif()
        endif()
    endforeach()

    # Каталог компилятора (для MinGW runtime / MSVC CRT)
    if(CDU_DEPLOY_INCLUDE_TOOLCHAIN_BIN)
        get_filename_component(_toolchain_bin "${CMAKE_CXX_COMPILER}" DIRECTORY)
        if(_toolchain_bin)
            list(APPEND _dirs "${_toolchain_bin}")
        endif()
    endif()

    # Каталоги импортированных таргетов, на которые ссылаемся
    set(_to_scan "${main_target}")
    get_target_property(_plugins ${main_target} TARGET_PLUGINS)
    if(_plugins)
        list(APPEND _to_scan ${_plugins})
    endif()

    foreach(_t IN LISTS _to_scan)
        if(NOT TARGET "${_t}")
            continue()
        endif()
        get_target_property(_links ${_t} LINK_LIBRARIES)
        foreach(_lk IN LISTS _links)
            if(TARGET "${_lk}")
                # Попробуем взять физическое расположение артефакта
                get_target_property(_loc "${_lk}" IMPORTED_LOCATION_${CMAKE_INSTALL_CONFIG_NAME})
                if(NOT _loc)
                    get_target_property(_loc "${_lk}" IMPORTED_LOCATION)
                endif()
                if(_loc)
                    get_filename_component(_l_dir "${_loc}" DIRECTORY)
                    if(EXISTS "${_l_dir}")
                        list(APPEND _dirs "${_l_dir}")
                    endif()
                else()
                    # если это наш собранный таргет, добавим его каталог
                    if(TARGET "${_lk}")
                        list(APPEND _dirs "$<TARGET_FILE_DIR:${_lk}>")
                    endif()
                endif()
            else()
                # Может быть просто путём к библиотеке
                if(EXISTS "${_lk}")
                    get_filename_component(_l_dir "${_lk}" DIRECTORY)
                    list(APPEND _dirs "${_l_dir}")
                endif()
            endif()
        endforeach()
    endforeach()

    # Пользовательские дополнительные каталоги
    if(CDU_DEPLOY_ADDITIONAL_DIRS)
        list(APPEND _dirs ${CDU_DEPLOY_ADDITIONAL_DIRS})
    endif()

    # Убираем дубликаты
    list(REMOVE_DUPLICATES _dirs)
    set(${out_var} "${_dirs}" PARENT_SCOPE)
endfunction()

##
# @brief (Внутренняя) Формирует списки регулярных выражений для исключения системных библиотек.
#
# @param pre_var Переменная для PRE_EXCLUDE_REGEXES.
# @param post_var Переменная для POST_EXCLUDE_REGEXES.
#
function(_CDU_collect_exclude_regexes pre_var post_var)
    set(_pre "")
    set(_post "")

    if(WIN32)
        # Отсекаем системные библиотеки Windows и api-ms-win-* runtime
        list(APPEND _post
            ".*[\\/][Ww]indows[\\/]System32[\\/].*"
            ".*[\\/]system32[\\/].*"
            "api-ms-win-.*"
            "ext-ms-.*"
        )
        # Частая ловушка: не копировать зависимости из QtCreator/bin
        list(APPEND _post ".*[\\/]QtCreator[\\/]bin[\\/].*")
    elseif(APPLE)
        list(APPEND _post
            "^/System/Library/.*"
            "^/usr/lib/.*"
        )
    else() # Linux/Unix
        list(APPEND _post
            "^/lib(64)?/.*"
            "^/usr/lib(64)?/.*"
        )
    endif()

    if(CDU_DEPLOY_EXTRA_POST_EXCLUDE_REGEXES)
        list(APPEND _post ${CDU_DEPLOY_EXTRA_POST_EXCLUDE_REGEXES})
    endif()

    set(${pre_var}  "${_pre}"  PARENT_SCOPE)
    set(${post_var} "${_post}" PARENT_SCOPE)
endfunction()

# ========================================================================================
# Основная функция деплоя
# ========================================================================================

##
# @brief (Внутренняя) Настраивает установку (install) и деплой для таргета.
#
# Эта функция выполняет следующие шаги:
#   1. Устанавливает основной исполняемый файл.
#   2. Устанавливает все связанные плагины в их поддиректории.
#   3. Генерирует `install(CODE)` скрипт, который во время установки (`cmake --install`)
#      выполнит `file(GET_RUNTIME_DEPENDENCIES)` для поиска и копирования всех
#      необходимых зависимостей (DLL, .so, и т.д.) в директорию с приложением.
#
# @param name Имя таргета для деплоя.
#
function(_CDU_declare_deploy name)
    if(NOT TARGET ${name})
        CDU_warning("_CDU_declare_deploy: Таргет '${name}' не найден. Пропуск…")
        return()
    endif()

    # Куда ставим основной исполняемый файл
    get_target_property(install_destination ${name} INSTALL_DIR)
    if(NOT install_destination)
        CDU_warning("For target '${name}' INSTALL_DIR not specified. Skipping...")
        return()
    endif()

    # Устанавливаем основной exe/bundle
    install(TARGETS ${name}
        RUNTIME DESTINATION ${install_destination}
        BUNDLE  DESTINATION ${install_destination}
        COMPONENT ${name}
    )

    # Устанавливаем плагины (если есть)
    set(app_plugins "")
    get_target_property(app_plugins ${name} TARGET_PLUGINS)
    set(_plugin_files "")
    if(app_plugins)
        CDU_debug("Starting deploying plugins for '${name}': ${app_plugins}")
        foreach(plugin_name IN LISTS app_plugins)
            _CDU_get_real_target_name(real_plugin_name ${plugin_name})

            if(NOT TARGET ${real_plugin_name})
                CDU_warning("Plugin target '${plugin_name}' not found. Skipping...")
                continue()
            endif()

            get_target_property(is_plugin ${real_plugin_name} IS_PLUGIN)
            if(NOT is_plugin)
                CDU_warning("Target '${plugin_name}' not marked as plugin (IS_PLUGIN). Skipping")
                continue()
            endif()

            get_target_property(category ${real_plugin_name} PLUGIN_CATEGORY)
            set(plugin_install_dir "${install_destination}/plugins/${category}")

            install(TARGETS ${real_plugin_name}
                RUNTIME DESTINATION "${plugin_install_dir}"
                LIBRARY DESTINATION "${plugin_install_dir}"
                COMPONENT ${name}
            )

            # Для сканирования зависимостей нам нужен путь файла плагина
            list(APPEND _plugin_files "$<TARGET_FILE:${real_plugin_name}>")
        endforeach()
    endif()

    # Устанавливаем пакеты с данными (если есть)
    set(app_packages "")
    get_target_property(app_packages ${name} TARGET_PACKAGES)
    if(app_packages)
        CDU_debug("Starting deploying packages for '${name}': ${app_packages}")
        foreach(package_name IN LISTS app_packages)
            _CDU_get_real_target_name(real_package_name ${package_name})

            if(NOT TARGET ${real_package_name})
                CDU_warning("Package target '${package_name}' not found. Skipping...")
                continue()
            endif()

            get_target_property(is_package ${real_package_name} IS_PACKAGE)
            if(NOT is_package)
                CDU_warning("Target '${package_name}' not marked as package (IS_PACKAGE). Skipping")
                continue()
            endif()

            get_target_property(package_files ${real_package_name} PACKAGE_FILES)
            get_target_property(package_dest ${real_package_name} PACKAGE_DESTINATION)
            get_target_property(package_dir ${real_package_name} SOURCE_DIR)

            if (package_files AND EXISTS "${package_dir}")
                set(pak_install_files)

                foreach(package_file IN LISTS package_files)
                    file(RELATIVE_PATH file_relative "${package_dir}" "${package_file}")
                    get_filename_component(file_relative_dir "${file_relative}" DIRECTORY)

                    install(FILES ${package_file}
                        DESTINATION "${install_destination}/${package_dest}/${file_relative_dir}"
                        COMPONENT ${name}
                    )

                endforeach()
                CDU_debug("Configured installation for package '${package_name}' to '${install_destination}/${package_dest}'")
            endif()
        endforeach()
    endif()

    # Сканируем зависимости и копируем их в корень приложения (универсально)
    _CDU_collect_runtime_dirs(_dep_dirs ${name})
    _CDU_collect_exclude_regexes(_pre_excl _post_excl)

    # Преобразуем списки в строки для передачи в install(CODE)
    list(JOIN _dep_dirs  ";" _dirs_list)
    list(JOIN _pre_excl  ";" _pre_list)
    list(JOIN _post_excl ";" _post_list)

    string(REPLACE "\\" "\\\\" _pre_list  "${_pre_list}")
    string(REPLACE "\\" "\\\\" _post_list "${_post_list}")

    # Список бинарников для сканирования: основной exe + плагины
    set(_execs_list "$<TARGET_FILE:${name}>")
    if(_plugin_files)
        list(JOIN _plugin_files ";" _plugin_joined)
        set(_execs_list "${_execs_list};${_plugin_joined}")
    endif()

    # Итоговая папка установки
    set(_dst "${CMAKE_INSTALL_PREFIX}/${install_destination}")

    # Генерируем скрипт, который будет выполнен на этапе `cmake --install`
    install(CODE "
            message(STATUS \"[CDU][DEPLOY] Scanning runtime deps for: ${name}\")

            set(_execs \"${_execs_list}\")
            set(_dirs \"${_dirs_list}\")
            set(_pre \"${_pre_list}\")
            set(_post \"${_post_list}\")
            set(_dst \"${_dst}\")

            message(STATUS \"[CDU][DEPLOY] EXECUTABLES=\${_execs}\")
            message(STATUS \"[CDU][DEPLOY] DIRECTORIES=\${_dirs}\")
            message(STATUS \"[CDU][DEPLOY] POST_EXCLUDE=\${_post}\")

            file(GET_RUNTIME_DEPENDENCIES
                EXECUTABLES \${_execs}
                DIRECTORIES \${_dirs}
                PRE_EXCLUDE_REGEXES \${_pre}
                POST_EXCLUDE_REGEXES \${_post}
                RESOLVED_DEPENDENCIES_VAR deps
                UNRESOLVED_DEPENDENCIES_VAR bad
            )

            if(bad)
                message(WARNING \"[CDU][DEPLOY] Unresolved deps:\\n\${bad}\")
            endif()

            foreach(f IN LISTS deps)
                file(COPY \"\${f}\" DESTINATION \"\${_dst}\")
            endforeach()

            message(STATUS \"[CDU][DEPLOY] Copied deps: \${deps}\")
        "
    )

    CDU_debug("Deploy-script for '${name}' is configured.")
endfunction()

CDU_debug("Module 'CDU_deploy' (universal GET_RUNTIME_DEPENDENCIES) loaded.")
