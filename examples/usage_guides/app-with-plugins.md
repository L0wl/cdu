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
# Объявляем плагин с именем 'plugin_a' и категорией 'formats'
# Категория определяет, в какую подпапку он будет установлен
declare_plugin(plugin_a "formats"
    SOURCES
        src/plugin_a.cpp
)
```

**`plugins/format_b/CMakeLists.txt`**
```cmake
# Объявляем плагин с именем 'plugin_b' и той же категорией 'formats'
declare_plugin(plugin_b "formats"
    SOURCES
        src/plugin_b.cpp
)
```

**`plugins/CMakeLists.txt`**
```cmake
# Включаем все плагины
include_projects()
```

**`apps/my_app/CMakeLists.txt`**
```cmake
# Объявляем приложение и указываем, какие плагины ему нужны
declare_application(my_app
    SOURCES
        src/main.cpp
    PLUGINS # Ключевое слово для указания плагинов
        plugin_a
        plugin_b
)
```

**Главный `CMakeLists.txt`**
```cmake
cmake_minimum_required(VERSION 3.21)
project(AppWithPlugins)

# 1. Подключаем CDU
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/cdu")
include(cdu)

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
        └── plugins/            # Директория с плагинами
            └── formats/
                ├── plugin_a.dll
                └── plugin_b.dll
```

CDU автоматически скопировал приложение, его рантайм-зависимости и все указанные плагины в правильные поддиректории.
