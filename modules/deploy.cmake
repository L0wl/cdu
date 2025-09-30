# ========================================================================================
# CMake Deploy Utilities (CDU) - Модуль деплоя
#
# Готовит install() и подтягивает рантайм-зависимости через внешний скрипт.
# Wrapper для install(SCRIPT) генерится через file(GENERATE) — генераторные
# выражения ($<TARGET_FILE:...>) разворачиваются заранее и корректны на Windows.
# ========================================================================================

if(CDU_DEPLOY_MODULE_LOADED)
    return()
endif()
set(CDU_DEPLOY_MODULE_LOADED TRUE)

include(GNUInstallDirs)

# --- fallback, если не настроили в cdu.cmake ---
if(NOT DEFINED CDU_SCRIPTS_DIR OR CDU_SCRIPTS_DIR STREQUAL "")
    get_filename_component(_cdu_mod_dir "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)
    get_filename_component(_cdu_base_dir "${_cdu_mod_dir}" DIRECTORY)
    set(CDU_SCRIPTS_DIR "${_cdu_base_dir}/scripts")
endif()

if(NOT DEFINED CDU_DEPLOY_DEREF_SYMLINKS)
    option(CDU_DEPLOY_DEREF_SYMLINKS "Копировать целевой файл по симлинку, сохраняя имя ссылки" ON)
endif()

function(_CDU_collect_runtime_dirs out_var main_target)
    set(_dirs "")
    list(APPEND _dirs "${CMAKE_BINARY_DIR}")
    list(APPEND _dirs "${CMAKE_BINARY_DIR}/bin")
    list(APPEND _dirs "${CMAKE_BINARY_DIR}/lib")

    foreach(tgt IN LISTS CDU_DECLARED_TARGETS)
        if(TARGET "${tgt}")
            get_target_property(_type ${tgt} TYPE)
            get_target_property(_is_plugin ${tgt} IS_PLUGIN)
            if(_type STREQUAL "SHARED_LIBRARY" OR _is_plugin)
                list(APPEND _dirs "$<TARGET_FILE_DIR:${tgt}>")
            endif()
        endif()
    endforeach()

    if(CDU_DEPLOY_INCLUDE_TOOLCHAIN_BIN)
        get_filename_component(_toolchain_bin "${CMAKE_CXX_COMPILER}" DIRECTORY)
        if(_toolchain_bin)
            list(APPEND _dirs "${_toolchain_bin}")
        endif()
    endif()

    _CDU_get_real_target_name(_real_main_target ${main_target})
    set(_to_scan "${_real_main_target}")
    get_target_property(_plugins ${_real_main_target} TARGET_PLUGINS)
    if(_plugins)
        list(APPEND _to_scan ${_plugins})
    endif()

    foreach(_t IN LISTS _to_scan)
        _CDU_get_real_target_name(_real_t "${_t}")
        if(NOT TARGET "${_real_t}")
            continue()
        endif()
        get_target_property(_links ${_real_t} LINK_LIBRARIES)
        foreach(_lk IN LISTS _links)
            _CDU_get_real_target_name(_real_link "${_lk}")
            if(TARGET "${_real_link}")
                get_target_property(_loc "${_real_link}" IMPORTED_LOCATION_${CMAKE_INSTALL_CONFIG_NAME})
                if(NOT _loc)
                    get_target_property(_loc "${_real_link}" IMPORTED_LOCATION)
                endif()
                if(_loc)
                    get_filename_component(_l_dir "${_loc}" DIRECTORY)
                    if(EXISTS "${_l_dir}")
                        list(APPEND _dirs "${_l_dir}")
                    endif()
                else()
                    list(APPEND _dirs "$<TARGET_FILE_DIR:${_real_link}>")
                endif()
            else()
                if(EXISTS "${_real_link}")
                    get_filename_component(_l_dir "${_real_link}" DIRECTORY)
                    list(APPEND _dirs "${_l_dir}")
                endif()
            endif()
        endforeach()
    endforeach()

    if(CDU_DEPLOY_ADDITIONAL_DIRS)
        list(APPEND _dirs ${CDU_DEPLOY_ADDITIONAL_DIRS})
    endif()

    list(REMOVE_DUPLICATES _dirs)
    set(${out_var} "${_dirs}" PARENT_SCOPE)
endfunction()

function(_CDU_collect_exclude_regexes pre_var post_var)
    set(_pre "")
    set(_post "")

    if(WIN32)
        list(APPEND _post
            ".*[\\/][Ww]indows[\\/]System32[\\/].*"
            ".*[\\/]system32[\\/].*"
            "api-ms-win-.*"
            "ext-ms-.*"
            ".*[\\/]QtCreator[\\/]bin[\\/].*"
        )
    elseif(APPLE)
        list(APPEND _post "^/System/Library/.*" "^/usr/lib/.*")
    else()
        list(APPEND _post "^/lib(64)?/.*" "^/usr/lib(64)?/.*")
    endif()

    if(CDU_DEPLOY_EXTRA_POST_EXCLUDE_REGEXES)
        list(APPEND _post ${CDU_DEPLOY_EXTRA_POST_EXCLUDE_REGEXES})
    endif()

    set(${pre_var}  "${_pre}"  PARENT_SCOPE)
    set(${post_var} "${_post}" PARENT_SCOPE)
endfunction()

function(_CDU_declare_deploy name)
    if(NOT TARGET ${name})
        CDU_warning("_CDU_declare_deploy: таргет '${name}' не найден. Пропуск.")
        return()
    endif()

    get_target_property(install_destination ${name} INSTALL_DIR)
    if(NOT install_destination)
        CDU_warning("For target '${name}' INSTALL_DIR не указан. Пропуск.")
        return()
    endif()

    install(TARGETS ${name}
        RUNTIME DESTINATION ${install_destination}
        LIBRARY DESTINATION ${install_destination}
        BUNDLE  DESTINATION ${install_destination}
        COMPONENT ${name}
    )

    set(app_plugins "")
    get_target_property(app_plugins ${name} TARGET_PLUGINS)
    set(_plugin_files "")
    if(app_plugins)
        foreach(plugin_name IN LISTS app_plugins)
            _CDU_get_real_target_name(real_plugin_name ${plugin_name})
            if(NOT TARGET ${real_plugin_name})
                CDU_warning("Plugin target '${plugin_name}' не найден. Пропуск.")
                continue()
            endif()
            get_target_property(is_plugin ${real_plugin_name} IS_PLUGIN)
            if(NOT is_plugin)
                CDU_warning("Target '${plugin_name}' не помечен как плагин (IS_PLUGIN). Пропуск.")
                continue()
            endif()

            get_target_property(category ${real_plugin_name} PLUGIN_CATEGORY)
            if(NOT category)
                set(category "misc")
            endif()
            set(plugin_install_dir "${install_destination}/plugins/${category}")

            install(TARGETS ${real_plugin_name}
                RUNTIME DESTINATION "${plugin_install_dir}"
                LIBRARY DESTINATION "${plugin_install_dir}"
                COMPONENT ${name}
            )

            if(UNIX)
                file(TO_CMAKE_PATH "${CMAKE_INSTALL_PREFIX}/${plugin_install_dir}" _abs_plugin_dir)
                file(TO_CMAKE_PATH "${CMAKE_INSTALL_PREFIX}/${install_destination}" _abs_app_dir)
                file(RELATIVE_PATH _rel_to_app "${_abs_plugin_dir}" "${_abs_app_dir}")
                if(_rel_to_app STREQUAL "")
                    set(_rel_to_app ".")
                endif()
                string(REPLACE "\\" "/" _rel_to_app "${_rel_to_app}")

                if(APPLE)
                    set_target_properties(${real_plugin_name} PROPERTIES
                        BUILD_WITH_INSTALL_RPATH TRUE
                        INSTALL_RPATH "@loader_path;@loader_path/${_rel_to_app}"
                        INSTALL_RPATH_USE_LINK_PATH TRUE
                    )
                else()
                    set_target_properties(${real_plugin_name} PROPERTIES
                        BUILD_WITH_INSTALL_RPATH TRUE
                        INSTALL_RPATH "\$ORIGIN;\$ORIGIN/${_rel_to_app}"
                        INSTALL_RPATH_USE_LINK_PATH TRUE
                    )
                endif()
            endif()

            list(APPEND _plugin_files "$<TARGET_FILE:${real_plugin_name}>")
        endforeach()
    endif()

    set(app_packages "")
    get_target_property(app_packages ${name} TARGET_PACKAGES)
    if(app_packages)
        foreach(package_name IN LISTS app_packages)
            _CDU_get_real_target_name(real_package_name ${package_name})
            if(NOT TARGET ${real_package_name})
                CDU_warning("Package target '${package_name}' не найден. Пропуск.")
                continue()
            endif()
            get_target_property(is_package ${real_package_name} IS_PACKAGE)
            if(NOT is_package)
                CDU_warning("Target '${package_name}' не помечен как package (IS_PACKAGE). Пропуск.")
                continue()
            endif()

            get_target_property(package_files ${real_package_name} PACKAGE_FILES)
            get_target_property(package_dest  ${real_package_name} PACKAGE_DESTINATION)
            get_target_property(package_dir   ${real_package_name} SOURCE_DIR)

            if (package_files AND EXISTS "${package_dir}")
                foreach(package_file IN LISTS package_files)
                    file(RELATIVE_PATH file_relative "${package_dir}" "${package_file}")
                    get_filename_component(file_relative_dir "${file_relative}" DIRECTORY)
                    install(FILES ${package_file}
                        DESTINATION "${install_destination}/${package_dest}/${file_relative_dir}"
                        COMPONENT ${name}
                    )
                endforeach()
                CDU_debug("Configured package '${package_name}' -> '${install_destination}/${package_dest}'")
            endif()
        endforeach()
    endif()

    _CDU_collect_runtime_dirs(_dep_dirs ${name})
    _CDU_collect_exclude_regexes(_pre_excl _post_excl)

    # Итоговая папка установки
    set(_dst "${CMAKE_INSTALL_PREFIX}/${install_destination}")
    set(_execs)
    list(APPEND _execs "$<TARGET_FILE:${name}>")
    if(_plugin_files)
        list(APPEND _execs ${_plugin_files})
    endif()

    # Хелпер: превращает список в набор строк по одному аргументу в кавычках и с переводами строк.
    # Пример результата:
    #   "val1"
    #   "val 2 with spaces"
    function(_CDU_quote_list_to_lines out_var)
        set(_res "")
        foreach(_x IN LISTS ARGN)
            if(NOT _x)
                continue()
            endif()

            # Экранируем бэкслэши, чтобы Windows пути не портили синтаксис
            string(REPLACE "\\" "\\\\" _x_esc "${_x}")
            string(APPEND _res "  \"${_x_esc}\"\n")
        endforeach()
        set(${out_var} "${_res}" PARENT_SCOPE)
    endfunction()

    _CDU_quote_list_to_lines(_Q_EXEC_LINES ${_execs})
    _CDU_quote_list_to_lines(_Q_DIRS_LINES ${_dep_dirs})
    _CDU_quote_list_to_lines(_Q_PRE_LINES  ${_pre_excl})
    _CDU_quote_list_to_lines(_Q_POST_LINES ${_post_excl})

    set(_install_content "")
    string(APPEND _install_content
        "# Auto-generated by CDU\n"
        "set(_CDU_EXECUTABLES\n${_Q_EXEC_LINES})\n"
        "set(_CDU_DIRECTORIES\n${_Q_DIRS_LINES})\n"
        "set(_CDU_PRE_EXCLUDE\n${_Q_PRE_LINES})\n"
        "set(_CDU_POST_EXCLUDE\n${_Q_POST_LINES})\n"
        "set(_CDU_DST \"${_dst}\")\n"
        "set(_CDU_DEREF_SYMLINKS ${CDU_DEPLOY_DEREF_SYMLINKS})\n"
        "include(\"${CDU_SCRIPTS_DIR}/cdu_deploy_runtime.cmake\")\n"
    )

    set(_install_driver "${CMAKE_CURRENT_BINARY_DIR}/cdu_install_${name}.cmake")
    file(GENERATE OUTPUT "${_install_driver}" CONTENT "${_install_content}")
    install(SCRIPT "${_install_driver}" COMPONENT ${name})
    CDU_debug("Deploy-script for '${name}' is configured (wrapper: ${_wrapper}).")
endfunction()

function(_CDU_deploy_qt_app name)
    if(QT_DEFAULT_MAJOR_VERSION EQUAL 6)
        get_target_property(${name}_install_dir ${name} INSTALL_DIR)
        if(${name}_install_dir)
            qt_generate_deploy_script(TARGET ${name}
                OUTPUT_SCRIPT deploy_${name}_script
                CONTENT "
                    qt_deploy_runtime_dependencies(EXECUTABLE $<TARGET_FILE:${name}>
                        BIN_DIR ${${name}_install_dir}
                        LIB_DIR ${${name}_install_dir}
                        QML_DIR ${${name}_install_dir}
                        LIBEXEC_DIR ${${name}_install_dir}
                        PLUGINS_DIR ${${name}_install_dir}/plugins
                        NO_TRANSLATIONS
                    )
                "
            )

            install(SCRIPT ${deploy_${name}_script})
        endif()
    endif()
endfunction()

CDU_debug("Module 'CDU_deploy' (runtime deps via external script) loaded.")
