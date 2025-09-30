# Пример 2: Приложение с библиотекой

Этот пример демонстрирует, как объявить статическую библиотеку и связать ее с приложением.

## 1. Структура проекта

Мы разделим код на приложение (`apps/`) и библиотеку (`libs/`).

```
my_project/
├── cmake/
│   └── cdu/          # Файлы CDU
├── apps/
│   ├── my_app/
│   │   ├── src/main.cpp
│   │   └── CMakeLists.txt
│   └── CMakeLists.txt
├── libs/
│   ├── my_lib/
│   │   ├── include/my_lib/my_lib.h
│   │   ├── src/my_lib.cpp
│   │   └── CMakeLists.txt
│   └── CMakeLists.txt
└── CMakeLists.txt    # Главный CMake-файл
```

## 2. Код библиотеки

**`libs/my_lib/include/my_lib/my_lib.h`**
```cpp
#pragma once
void print_message();
```

**`libs/my_lib/src/my_lib.cpp`**
```cpp
#include <my_lib/my_lib.h>
#include <iostream>

void print_message() {
    std::cout << "Hello from my_lib!" << std::endl;
}
```

## 3. Код приложения

**`apps/my_app/src/main.cpp`**
```cpp
#include <my_lib/my_lib.h>

int main() {
    print_message();
    return 0;
}
```

## 4. Настройка CMake

**`libs/my_lib/CMakeLists.txt`**
```cmake
project(my_lib VERSION 1.0.0)
file(GLOB_RECURSE ${PROJECT_NAME}_SOURCES "src/*.cpp" "include/*.h")

# Объявляем статическую библиотеку
declare_library(${PROJECT_NAME} STATIC
    SOURCES ${${PROJECT_NAME}_SOURCES} # Включение всех исходников библиотеки (важно)
    # Цель автоматически экспортируется как AppWithLibrary::my_lib
    # Директория include/ доступна для других таргетов
    # без $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
)
```

**`apps/my_app/CMakeLists.txt`**
```cmake
project(my_app VERSION 1.0.0)

# Объявляем приложение и линкуем его с библиотекой
file(GLOB_RECURSE ${PROJECT_NAME}_SOURCES "src/*.cpp" "include/*.h")

declare_application(${PROJECT_NAME}
    SOURCES ${${PROJECT_NAME}_SOURCES}
    PUBLIC AppWithLibrary::my_lib # Линкуемся с библиотекой по пространству имён.
)
```

**`libs/CMakeLists.txt` и `apps/CMakeLists.txt`**

Эти файлы просто ищут и подключают все проекты в своих поддиректориях.
```cmake
include_projects()
```

**Главный `CMakeLists.txt`**
```cmake
cmake_minimum_required(VERSION 3.21)
project(AppWithLibrary)

# 1. Подключаем CDU
include(cmake/cdu/cdu.cmake)

# 2. Включаем директории с библиотеками и приложениями
add_subdirectory(libs)
add_subdirectory(apps)
```

Теперь при сборке CDU автоматически обработает зависимости, и `my_app` будет успешно скомпилирован с использованием `my_lib`.
