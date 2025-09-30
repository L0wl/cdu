# Пример 3: Приложение с плагинами

Этот пример показывает, как создать плагины и настроить их развертывание (деплой) вместе с основным приложением.

## 1. Структура проекта

```
my_project/
├── cmake/
│   └── cdu/          # Файлы CDU
├── apps/
│   └── my_app/       # Директория приложения
│       └── ...
├── plugins/
│   ├── CMakeLists.txt
│   ├── format_a/
│   │   ├── src/plugin_a.cpp
│   │   └── CMakeLists.txt
│   └── format_b/
│       ├── src/plugin_b.cpp
│       └── CMakeLists.txt
└── CMakeLists.txt
```

## 2. Настройка CMake

**`plugins/format_a/CMakeLists.txt`**
```cmake
project(plugin_a VERSION 1.0.0)
# Объявляем плагин с именем 'plugin_a' и категорией 'formats'
# Категория определяет, в какую подпапку он будет установлен

find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Core Xml)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core Xml)

file(GLOB_RECURSE ${PROJECT_NAME}_SOURCES "src/*.cpp" "include/*.h")

declare_plugin(${PROJECT_NAME} "formats"
    SOURCES ${${PROJECT_NAME}_SOURCES}
    # Цель автоматически экспортируется как AppWithPlugins::plugin_a
    PRIVATE Qt${QT_VERSION_MAJOR}::Core Qt${QT_VERSION_MAJOR}::Xml
)
```

**`plugins/format_b/CMakeLists.txt`**
```cmake
project(plugin_b VERSION 1.0.0)

find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Core Xml)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core Xml)

file(GLOB_RECURSE ${PROJECT_NAME}_SOURCES "src/*.cpp" "include/*.h")

# Объявляем плагин с именем 'plugin_b' и той же категорией 'formats'
declare_plugin(${PROJECT_NAME} "formats"
    SOURCES ${${PROJECT_NAME}_SOURCES}
    # Цель автоматически экспортируется как AppWithPlugins::plugin_b
    PRIVATE Qt${QT_VERSION_MAJOR}::Core Qt${QT_VERSION_MAJOR}::Xml
)
```

**`plugins/CMakeLists.txt`**
```cmake
# Включаем все плагины
include_projects()
```

**`apps/my_app/CMakeLists.txt`**
```cmake
project(my_app VERSION 1.0.0)

find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Core)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core)
file(GLOB_RECURSE ${PROJECT_NAME}_SOURCES "src/*.cpp" "include/*.h")

# Объявляем приложение и указываем, какие плагины ему нужны
declare_application(${PROJECT_NAME}
    SOURCES ${${PROJECT_NAME}_SOURCES}
    PLUGINS # Ключевое слово для указания плагинов
        AppWithPlugins::plugin_a # Можно так-же указать plugin_a
        AppWithPlugins::plugin_b # Можно так-же указать plugin_b
    PRIVATE Qt${QT_VERSION_MAJOR}::Core
)
```

**Главный `CMakeLists.txt`**
```cmake
cmake_minimum_required(VERSION 3.21)
project(AppWithPlugins)

# 1. Подключаем CDU
include(cmake/cdu/cdu.cmake)

# 2. Включаем директории
add_subdirectory(plugins)
add_subdirectory(apps)
```

## 3. Развертывание (Deploy)

После сборки проекта выполните команду установки:

```bash
# Указываем директорию для установки
cmake --install build --prefix ./install
```

В результате вы получите следующую структуру в папке `install/`:

```
install/
└── apps/
    └── my_app/
        ├── my_app.exe          # Исполняемый файл
        ├── Qt6Core.dll         # Зависимости приложения
        ├── Qt6Xml.dll          # Зависимости плагина будут здесь
        └── plugins/            # Директория с плагинами
            └── formats/
                ├── plugin_a.dll
                └── plugin_b.dll
```

CDU автоматически скопировал приложение, его рантайм-зависимости и все указанные плагины в правильные поддиректории.
