# cdu_deploy_runtime.cmake
# Ожидает заранее установленные переменные:
#   _CDU_EXECUTABLES       (list)
#   _CDU_DIRECTORIES       (list)
#   _CDU_PRE_EXCLUDE       (list)
#   _CDU_POST_EXCLUDE      (list)
#   _CDU_DST               (string, абсолютный путь назначения)
#   _CDU_DEREF_SYMLINKS    (ON/OFF)

if(NOT DEFINED _CDU_DST)
    message(FATAL_ERROR "[CDU][DEPLOY] _CDU_DST is not set")
endif()

# Немного отладочного вывода — полезно в логах установки
message(STATUS "[CDU][DEPLOY] EXECUTABLES=${_CDU_EXECUTABLES}")
message(STATUS "[CDU][DEPLOY] DIRECTORIES=${_CDU_DIRECTORIES}")
if(_CDU_PRE_EXCLUDE)
    message(STATUS "[CDU][DEPLOY] PRE_EXCLUDE=${_CDU_PRE_EXCLUDE}")
endif()
if(_CDU_POST_EXCLUDE)
    message(STATUS "[CDU][DEPLOY] POST_EXCLUDE=${_CDU_POST_EXCLUDE}")
endif()

file(GET_RUNTIME_DEPENDENCIES
    EXECUTABLES               ${_CDU_EXECUTABLES}
    DIRECTORIES               ${_CDU_DIRECTORIES}
    PRE_EXCLUDE_REGEXES       ${_CDU_PRE_EXCLUDE}
    POST_EXCLUDE_REGEXES      ${_CDU_POST_EXCLUDE}
    RESOLVED_DEPENDENCIES_VAR _CDU_DEPS
    UNRESOLVED_DEPENDENCIES_VAR _CDU_BAD
)

if(_CDU_BAD)
    message(WARNING "[CDU][DEPLOY] Unresolved deps:\n${_CDU_BAD}")
endif()

file(MAKE_DIRECTORY "${_CDU_DST}")

# Копируем зависимости.
# Если включен _CDU_DEREF_SYMLINKS и файл — симлинк,
# копируем целевой файл, НО ИМЕНЕМ ссылки (без создания ссылки).
foreach(f IN LISTS _CDU_DEPS)
    get_filename_component(_name "${f}" NAME)
    if(_CDU_DEREF_SYMLINKS)
        if(IS_SYMLINK "${f}")
            get_filename_component(_real "${f}" REALPATH)
            if(NOT EXISTS "${_real}")
                message(WARNING "[CDU][DEPLOY] Broken symlink: ${f}")
                continue()
            endif()
            file(COPY_FILE "${_real}" "${_CDU_DST}/${_name}")
        else()
            file(COPY_FILE "${f}" "${_CDU_DST}/${_name}")
        endif()
    else()
        if(IS_SYMLINK "${f}")
            # Сохраняем ссылку как ссылку
            file(READ_SYMLINK "${f}" _link_tgt)
            execute_process(COMMAND "${CMAKE_COMMAND}" -E create_symlink
                "${_link_tgt}" "${_CDU_DST}/${_name}")
        else()
            file(COPY_FILE "${f}" "${_CDU_DST}/${_name}")
        endif()
    endif()
endforeach()

message(STATUS "[CDU][DEPLOY] Copied deps: ${_CDU_DEPS}")
