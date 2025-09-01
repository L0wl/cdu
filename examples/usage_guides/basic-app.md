# Пример 1: Базовое приложение

Этот пример показывает, как с помощью CDU создать простое консольное приложение.

## 1. Структура проекта

Создайте следующую структуру директорий:

```
my_project/
├── cmake/
│   └── cdu/          # Здесь лежат файлы CDU
│       └── ...
├── src/
│   └── main.cpp      # Исходный код вашего приложения
└── CMakeLists.txt    # Главный CMake-файл проекта
```

## 2. Исходный код (`src/main.cpp`)

Это может быть любой простой C++ код.

```cpp
#include <iostream>

int main() {
    std::cout << "Hello, CDU!" << std::endl;
    return 0;
}
```

## 3. CMakeLists.txt

Это главный файл, где происходит вся магия.

```cmake
# Задаем минимальную версию CMake и имя проекта
cmake_minimum_required(VERSION 3.21)
project(MyFirstApp VERSION 1.0.0)

# 1. Подключаем CDU
# Предполагается, что CDU находится в папке cmake/cdu
include(cmake/cdu/cdu.cmake)

find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Core)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core)

# Нашли исходники относительно расположения этого файла
file(GLOB_RECURSE ${PROJECT_NAME}_SOURCES "src/*.cpp" "include/*.h")

# 2. Объявляем наше приложение
declare_application(${PROJECT_NAME}
    SOURCES ${${PROJECT_NAME}_SOURCES}
    PRIVATE Qt${QT_VERSION_MAJOR}::Core
)
```

## 4. Сборка

Теперь вы можете стандартным образом сконфигурировать и собрать проект. CDU позаботится обо всех деталях.

```bash
cd my_project
cmake -S . -B build
cmake --build build
```

После сборки вы найдете исполняемый файл в директории `build/`.
