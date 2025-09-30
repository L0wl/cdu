# Пример 4: Конфигурация CDU

CDU спроектирован так, чтобы быть гибким. Вы можете управлять его поведением, изменяя переменные в файле `cdu.cmake`.

## Централизованная конфигурация

**Никогда не редактируйте файлы в директории `modules/`!**

Все пользовательские настройки находятся в верхней части главного файла `cdu.cmake` в блоке `ПОЛЬЗОВАТЕЛЬСКАЯ КОНФИГУРАЦИЯ (User Configuration)`.

## Основные параметры

Откройте `cdu.cmake` и вы увидите следующие опции:

### 1. Логирование

- **`CDU_LOG_LEVEL`**: Устанавливает уровень детализации вывода. По умолчанию `INFO`.
  - `DEBUG`: Максимально подробный вывод для отладки.
  - `INFO`: Стандартный информационный вывод.
  - `WARNING`: Показывать только предупреждения и ошибки.
  - `ERROR`: Показывать только ошибки.
- **`CDU_DEBUG_MODE`**: Удобный переключатель (`ON`/`OFF`) для быстрого включения/выключения `DEBUG` уровня.

```cmake
# Пример: Включаем полную отладку
set(CDU_LOG_LEVEL "DEBUG" CACHE STRING "...")
set(CDU_DEBUG_MODE ON CACHE BOOL "...")
```

### 2. Настройки сборки

- **`CDU_PCH_FILE`**: Путь к файлу предкомпилированного заголовка (PCH). Если оставить путь пустым, PCH не будет использоваться.
  ```cmake
  # Отключаем PCH
  set(CDU_PCH_FILE "" CACHE STRING "...")
  ```
- **`CDU_TARGET_NAMESPACE`**: Пространство имён, в котором автоматически создаются цели проекта. По умолчанию совпадает с именем
  верхнеуровневого `project()`. Установите пустую строку, чтобы отключить генерацию таргетов вида `MyProject::Library`.
  Сгенерированные имена работают и при установке: CDU выпускает `find_package(MyProject CONFIG)` c экспортом всех библиотек и
  плагинов.
  ```cmake
  # Отключаем автоматические пространства имён
  set(CDU_TARGET_NAMESPACE "" CACHE STRING "...")
  ```
- **`CDU_RC_TEMPLATE`**: Путь к `.rc` файлу для информации о версии в Windows. Если оставить пустым, информация о версии не будет добавляться в бинарные файлы.
  ```cmake
  # Отключаем внедрение версии
  set(CDU_RC_TEMPLATE "" CACHE STRING "...")
  ```

### 3. Настройки развертывания (Deploy)

- **`CDU_DEPLOY_ADDITIONAL_DIRS`**: Позволяет указать дополнительные директории (через `;`), где CDU будет искать зависимости (DLL, .so) для копирования.
  ```cmake
  # Добавляем свою папку с библиотеками в поиск
  set(CDU_DEPLOY_ADDITIONAL_DIRS "C:/MyLibs/bin;D:/Another/path" CACHE STRING "...")
  ```
- **`CDU_DEPLOY_EXTRA_POST_EXCLUDE_REGEXES`**: Позволяет добавить свои правила для исключения ненужных библиотек из деплоя.
- **`CDU_DEPLOY_INCLUDE_TOOLCHAIN_BIN`**: Установите в `ON`, если ваши зависимости (например, `libgcc_s_seh-1.dll` для MinGW) находятся рядом с компилятором.

### 4. Настройка пресетом (CMakePresets)

- **`CMakePresets.json`**: Позволяет указать параметры конфигурации сборки только один раз, и потом переиспользовать сколько угодно. 
  ```jsonc
  {
      "version": 3,
      "cmakeMinimumRequired": {
          "major": 3,
          "minor": 21,
          "patch": 0
      },
      "configurePresets": [
          {
              "name": "windows-debug",
              "hidden": false,
              "generator": "MinGW Makefiles",
              "description": "Windows Debug build with Qt 6.8.2",
              "binaryDir": "${sourceDir}/.build/windows-debug",
              "cacheVariables": {
                  "CMAKE_BUILD_TYPE": "Debug",
                  "BUILD_TESTS": "ON",
                  "CDU_LOG_LEVEL": "INFO", // Параметр уровня лога деплоя
                  "CDU_DEPLOY_INCLUDE_TOOLCHAIN_BIN": "OFF", // Параметр включения деплоя утилит тулчейна (опционально)
                  "CDU_PCH_FILE": "${sourceDir}/templates/pch.h", // Параметр установки PCH файла (опционально)
                  "CDU_RC_TEMPLATE": "${sourceDir}/templates/version.rc.in", // Параметр установки шаблона файла ресурсов (опционально)
                  "CDU_PCH_UNSPECIFIED_DEFAULT_STATE": "ON", // Параметр стандартного поведения включения PCH (если не задано целью)
                  "CMAKE_TOOLCHAIN_FILE": "$env{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake", // Параметр интеграции с vcpk (опционально)
                  "VCPKG_TARGET_TRIPLET": "x64-mingw-static", // Параметр интеграции с vcpk (опционально)
                  "CMAKE_INSTALL_PREFIX": "${sourceDir}/.install/windows-debug", // Параметр директории деплоя (установки)
                  "CMAKE_PREFIX_PATH": "C:/Qt/6.8.2/mingw_64/lib/cmake", // Параметр тулчейна Qt (опционально)
                  "CMAKE_C_COMPILER": "C:/Qt/Tools/mingw1310_64/bin/gcc.exe", // Параметр компилятора C (опционально)
                  "CMAKE_CXX_COMPILER": "C:/Qt/Tools/mingw1310_64/bin/g++.exe", // Параметр компилятора C++ (опционально)
                  "CMAKE_MAKE_PROGRAM": "C:/Qt/Tools/mingw1310_64/bin/mingw32-make.exe", // Параметр компоновщика make (опционально)
                  "CMAKE_CXX_STANDARD": "20" // Параметр стандарта языка C++ (опционально)
              },
              "condition": {
                  "type": "equals",
                  "lhs": "${hostSystemName}",
                  "rhs": "Windows"
              }
          },
          {
              "name": "windows-release",
              "hidden": false,
              "generator": "MinGW Makefiles",
              "description": "Windows Release build with Qt 6.8.2",
              "binaryDir": "${sourceDir}/.build/windows-release",
              "cacheVariables": {
                  "CMAKE_BUILD_TYPE": "Release",
                  "BUILD_TESTS": "OFF",
                  "CDU_LOG_LEVEL": "INFO",
                  "CDU_DEPLOY_INCLUDE_TOOLCHAIN_BIN": "OFF",
                  "CDU_PCH_FILE": "${sourceDir}/templates/pch.h",
                  "CDU_RC_TEMPLATE": "${sourceDir}/templates/version.rc.in",
                  "CDU_PCH_UNSPECIFIED_DEFAULT_STATE": "ON",
                  "CMAKE_TOOLCHAIN_FILE": "$env{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake",
                  "VCPKG_TARGET_TRIPLET": "x64-mingw-static",
                  "CMAKE_INSTALL_PREFIX": "${sourceDir}/.install/windows-release",
                  "CMAKE_PREFIX_PATH": "C:/Qt/6.8.2/mingw_64/lib/cmake",
                  "CMAKE_C_COMPILER": "C:/Qt/Tools/mingw1310_64/bin/gcc.exe",
                  "CMAKE_CXX_COMPILER": "C:/Qt/Tools/mingw1310_64/bin/g++.exe",
                  "CMAKE_MAKE_PROGRAM": "C:/Qt/Tools/mingw1310_64/bin/mingw32-make.exe",
                  "CMAKE_CXX_STANDARD": "20"
              },
              "condition": {
                  "type": "equals",
                  "lhs": "${hostSystemName}",
                  "rhs": "Windows"
              }
          },
          {
              "name": "linux-debug",
              "hidden": false,
              "generator": "Unix Makefiles",
              "description": "Linux Debug build with Qt 6.8.2",
              "binaryDir": "${sourceDir}/.build/linux-debug",
              "cacheVariables": {
                  "CMAKE_BUILD_TYPE": "Debug",
                  "BUILD_TESTS": "ON",
                  "CMAKE_INSTALL_PREFIX": "${sourceDir}/.install/linux-debug",
                  "CMAKE_CXX_STANDARD": "20"
              },
              "condition": {
                  "type": "equals",
                  "lhs": "${hostSystemName}",
                  "rhs": "Linux"
              }
          },
          {
              "name": "linux-release",
              "hidden": false,
              "generator": "Unix Makefiles",
              "description": "Linux Release build with Qt 6.8.2",
              "binaryDir": "${sourceDir}/.build/linux-release",
              "cacheVariables": {
                  "CMAKE_BUILD_TYPE": "Release",
                  "BUILD_TESTS": "OFF",
                  "CMAKE_INSTALL_PREFIX": "${sourceDir}/.install/linux-release",
                  "CMAKE_CXX_STANDARD": "20"
              },
              "condition": {
                  "type": "equals",
                  "lhs": "${hostSystemName}",
                  "rhs": "Linux"
              }
          }
      ],
      "buildPresets": [
          {
              "name": "windows-debug",
              "configurePreset": "windows-debug",
              "description": "Build Windows Debug configuration",
              "cleanFirst": false,
              "targets": [
                  "all",
                  "install"
              ],
              "jobs": 6
          },
          {
              "name": "windows-release",
              "configurePreset": "windows-release",
              "description": "Build Windows Release configuration",
              "cleanFirst": true,
              "targets": [
                  "all",
                  "install"
              ],
              "jobs": 6
          },
          {
              "name": "linux-debug",
              "configurePreset": "linux-debug",
              "description": "Build Linux Debug configuration",
              "cleanFirst": false,
              "targets": [
                  "all",
                  "install"
              ],
              "jobs": 6
          },
          {
              "name": "linux-release",
              "configurePreset": "linux-release",
              "description": "Build Linux Release configuration",
              "cleanFirst": true,
              "targets": [
                  "all",
                  "install"
              ],
              "jobs": 6
          }
      ]
  }
  ```

Эти настройки позволяют тонко адаптировать CDU под нужды практически любого проекта.
