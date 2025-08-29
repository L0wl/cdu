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
# Объявляем статическую библиотеку
declare_library(my_lib STATIC
    SOURCES
        src/my_lib.cpp
    PUBLIC
        # Делаем директорию include/ доступной для других таргетов
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
)
```

**`apps/my_app/CMakeLists.txt`**
```cmake
# Объявляем приложение и линкуем его с библиотекой
declare_application(my_app
    SOURCES
        src/main.cpp
    PUBLIC
        my_lib # Линкуемся с my_lib
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
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/cdu")
include(cdu)

# 2. Включаем директории с библиотеками и приложениями
add_subdirectory(libs)
add_subdirectory(apps)
```

Теперь при сборке CDU автоматически обработает зависимости, и `my_app` будет успешно скомпилирован с использованием `my_lib`.
