# ========================================================================================
# CMake Deploy Utilities (CDU) - Автоматическое подключение подпроектов
#
# Эта утилита предоставляет функцию `include_projects()`, которая рекурсивно
# ищет все файлы CMakeLists.txt в директории проекта и автоматически
# добавляет их с помощью `add_subdirectory()`.
#
# Это избавляет от необходимости вручную прописывать каждый подпроект
# в корневом CMakeLists.txt.
# ========================================================================================

# Защита от повторного включения
if(CDU_INCLUDE_PROJECTS_LOADED)
    return()
endif()
set(CDU_INCLUDE_PROJECTS_LOADED TRUE)

# Рекурсивно ищет все CMakeLists.txt и добавляет их как поддиректории.
# Принимает опциональные аргументы - имена поддиректорий, которые нужно
# включить в первую очередь.
function(include_projects)
    set(priority_dirs ${ARGN})
    set(added_dirs "")

    # Включаем приоритетные директории
    foreach(dir ${priority_dirs})
        set(dir_path "${CMAKE_CURRENT_SOURCE_DIR}/${dir}")
        if(EXISTS "${dir_path}/CMakeLists.txt")
            add_subdirectory(${dir_path})
            list(APPEND added_dirs ${dir_path})
            CDU_debug("Added priority project: ${dir_path}")
        else()
            CDU_warning("Priority directory '${dir}' does not contain a CMakeLists.txt")
        endif()
    endforeach()

    # Ищем все CMakeLists.txt в поддиректориях (до 2 уровней вложенности)
    file(GLOB sub_cmakes LIST_DIRECTORIES false CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/*/CMakeLists.txt")
    file(GLOB sub_sub_cmakes LIST_DIRECTORIES false CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/*/*/CMakeLists.txt")
    set(all_cmakes ${sub_cmakes} ${sub_sub_cmakes})
    list(REMOVE_DUPLICATES all_cmakes)

    # Включаем остальные проекты
    foreach(cmake_file ${all_cmakes})
        get_filename_component(dir_path ${cmake_file} DIRECTORY)
        if(NOT (dir_path IN_LIST added_dirs))
            add_subdirectory(${dir_path})
            list(APPEND added_dirs ${dir_path})
            CDU_debug("Added project: ${dir_path}")
        endif()
    endforeach()
    CDU_info("Searching and connecting subprojects is completed.")
endfunction()
