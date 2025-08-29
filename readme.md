# CDU (CMake Deploy Utilities)

<p align=center><img src="https://img.shields.io/badge/License-MIT-yellow.svg" href="https://opensource.org/licenses/MIT"></img></p>

<p align="center">Русский&nbsp;&nbsp;|&nbsp;&nbsp;<a href="resources/readme_en.md">English</a></p>

**CDU** - это набор вспомогательных скриптов для CMake, которые кардинально упрощают сборку, настройку и развертывание C++ проектов. Система автоматизирует рутинные задачи и позволяет поддерживать чистоту и порядок в `CMakeLists.txt`.

> [!NOTE]
> Требуется CMake версии 3.21 или выше.

## Быстрый старт

### 1. Установка

Рекомендованно добавлять в свой проект модуль CDU как Git субмодуль

```bash
# Добавление CDU прямо в cmake/cdu папку
git submodule add https://github.com/L0wl/cdu.git cmake/cdu
```

### 2. Конфигурация

В корневом `CMakeLists.txt` вы просто подключаете CDU и поддиректории верхнего уровня:

```cmake
# Корневой cmake файл вашего проекта
cmake_minimum_required(VERSION 3.21)
project(MyAwesomeApp)

# 1. Подключение CDU разными способами
# Подключаем CDU #1 (Рекомендованно)
include(cmake/cdu/cdu.cmake)

# Подключение CDU #2 (Сложнааааа!)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/cdu")
include(cdu)

# 2. Включаем поддиректории с логическими частями проекта
add_subdirectory(libs)
add_subdirectory(plugins)
add_subdirectory(apps)
```

**Все настройки CDU централизованы в верхней части файла `cdu.cmake`.**

Вы можете легко изменять такие параметры, как:

- `CDU_LOG_LEVEL`: Уровень детализации логов (`INFO`, `DEBUG`).
- `CDU_PCH_FILE`: Путь к файлу предкомпилированных заголовков (оставьте пустым для отключения).
- `CDU_RC_TEMPLATE`: Путь к `.rc` файлу для информации о версии Windows (оставьте пустым для отключения).
- `CDU_DEPLOY_*`: Настройки для развертывания (дополнительные пути, исключения и т.д.).

Откройте `cdu.cmake`, чтобы увидеть полный список опций с комментариями.

## Философия и структура

CDU спроектирован для работы с иерархической структурой проектов, где каждая логическая часть (библиотека, плагин, приложение) находится в своей директории.

Вот пример того, как может выглядеть ваш проект при использовании CDU:

```
<repo-root>/
├── cmake/
│   └── cdu/                # Директория с CDU
│       └── ...
├── apps/
│   ├── CMakeLists.txt      # Использует include_projects() для включения всех приложений
│   └── gui_client/
│       └── CMakeLists.txt  # declare_application(gui_client ...)
├── libs/
│   ├── CMakeLists.txt      # Использует include_projects() для включения всех библиотек
│   └── core/
│       └── CMakeLists.txt  # declare_library(core ...)
├── plugins/
│   ├── CMakeLists.txt      # Использует include_projects() для включения всех плагинов
│   └── basic/
│       └── xml_adapter/
│           └── CMakeLists.txt # declare_plugin(xml_adapter "basic" ...)
└── CMakeLists.txt          # Корневой CMakeLists.txt, подключающий CDU
```

## Ключевые возможности

- **Простое объявление таргетов**: Функции `declare_application`, `declare_library`, `declare_plugin`.
- **Автоматизация для Windows**: Авто-генерация `version.rc`, подключение манифеста и иконки.
- **Предкомпилированные заголовки (PCH)**: Автоматическое создание и подключение PCH для ускорения сборки.
- **Управление зависимостями**: Автоматический поиск и копирование рантайм-зависимостей (DLL, .so) при установке.
- **Авто-включение подпроектов**: `include_projects()` для автоматического сканирования `CMakeLists.txt` в поддиректориях.

## Примеры и руководства

Лучший способ понять, как использовать CDU — посмотреть на примеры.

- **[Подробные руководства](./examples/usage_guides)**: Директория с текстовыми `.md` файлами, которые шаг за шагом описывают различные сценарии:
    1.  [Создание базового приложения](./examples/usage_guides/basic-app.md).
    2.  [Работа с библиотеками](./examples/usage_guides/app-with-plugins.md).
    3.  [Использование и развертывание плагинов](./examples/usage_guides/app-with-plugins.md).
    4.  [Тонкая настройка CDU](./examples/usage_guides/configuring-cdu.md).

## Справочник по API

Основной API предоставляется следующими функциями:

- `declare_application(...)`
- `declare_utility(...)`
- `declare_library(...)`
- `declare_plugin(...)`
- `include_projects()`

**Подробная документация по всем параметрам находится непосредственно в коде в виде комментариев** в файле `modules/api.cmake`. Внутренняя логика задокументирована в `modules/target.cmake` и `modules/deploy.cmake`.

## Лицензия

Этот проект распространяется под лицензией MIT. См. файл [`LICENSE`](./LICENSE) для получения дополнительной информации.
