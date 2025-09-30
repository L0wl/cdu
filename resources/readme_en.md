# CDU (CMake Deploy Utilities)

<p align=center><img src="https://img.shields.io/badge/License-MIT-yellow.svg" href="https://opensource.org/licenses/MIT"></img></p>

<p align="center">English&nbsp;&nbsp;|&nbsp;&nbsp;<a href="../readme.md">Русский</a></p>

**CDU** is a set of helper scripts for CMake that dramatically simplify building, configuring, and deploying C++ projects. The system automates routine tasks and helps maintain clean and organized `CMakeLists.txt` files.

> [!NOTE]
> Requires CMake version 3.21 or higher.

## Quick Start

### 1. Installation

It is recommended to add CDU to your project as a Git submodule.

```bash
# Add CDU to the cmake/cdu directory
git submodule add https://github.com/L0wl/cdu.git cmake/cdu
```

### 2. Configuration

In your root `CMakeLists.txt`, you simply include CDU and the top-level subdirectories:

```cmake
# Top-level project cmake file
cmake_minimum_required(VERSION 3.21)
project(MyAwesomeApp)

# 1. Include CDU with different approaches
# Including CDU #1st approach
include(cmake/cdu/cdu.cmake) # Recomended

# Including CDU #2nd approach
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/cdu")
include(cdu) # Sooo hard

# 2. Include subdirectories with logical project parts
add_subdirectory(libs)
add_subdirectory(plugins)
add_subdirectory(apps)
```

**All CDU settings are centralized at the top of the `cdu.cmake` file.**

You can easily change parameters such as:

- `CDU_LOG_LEVEL`: The verbosity level for logs (`INFO`, `DEBUG`).
- `CDU_PCH_FILE`: The path to the precompiled header file (leave empty to disable).
- `CDU_RC_TEMPLATE`: The path to the `.rc` file for Windows version information (leave empty to disable).
- `CDU_DEPLOY_*`: Settings for deployment (additional paths, exclusions, etc.).
- `CDU_TARGET_NAMESPACE`: Namespace applied to automatically exported targets (`<namespace>::MyLib`). Defaults to the root project name.

Open `cdu.cmake` to see the full list of options with comments.

## Philosophy and Structure

CDU is designed to work with a hierarchical project structure, where each logical part (library, plugin, application) resides in its own directory.

Here is an example of what your project structure might look like with CDU:

```
<repo-root>/
├── cmake/
│   └── cdu/                # Directory containing CDU
│       └── ...
├── apps/
│   ├── CMakeLists.txt      # Uses include_projects() to include all applications
│   └── gui_client/
│       └── CMakeLists.txt  # declare_application(gui_client ...)
├── libs/
│   ├── CMakeLists.txt      # Uses include_projects() to include all libraries
│   └── core/
│       └── CMakeLists.txt  # declare_library(core ...)
├── plugins/
│   ├── CMakeLists.txt      # Uses include_projects() to include all plugins
│   └── basic/
│       └── xml_adapter/
│           └── CMakeLists.txt # declare_plugin(xml_adapter "basic" ...)
└── CMakeLists.txt          # Root CMakeLists.txt that includes CDU
```

## Key Features

- **Simple Target Declaration**: Functions like `declare_application`, `declare_library`, `declare_plugin`.
- **Unified Target Namespace**: Each target is automatically exported as `<ProjectName>::Target`, making reuse inside and outside the project straightforward.
- **Windows Automation**: Auto-generation of `version.rc`, manifest, and icon linking.
- **Precompiled Headers (PCH)**: Automatic creation and linking of PCH to speed up builds.
- **Dependency Management**: Automatic discovery and copying of runtime dependencies (DLLs, .so) during installation.
- **Auto-Inclusion of Sub-projects**: `include_projects()` to automatically scan for `CMakeLists.txt` in subdirectories.

## Examples and Guides

The best way to learn how to use CDU is by looking at the examples.

- **[Detailed Guides](../examples/usage_guides)**: A directory with text-based `.md` files that provide step-by-step descriptions of various scenarios:
    1. [Creating a basic application](../examples/usage_guides/basic-app.md).
    2. [Working with libraries](../examples/usage_guides/app-with-library.md).
    3. [Using and deploying plugins](../examples/usage_guides/app-with-plugins.md).
    4. [Advanced configuration of CDU](../examples/usage_guides/configuring-cdu.md).

## API Reference

The main API is provided by the following functions:

- `declare_application(...)`
- `declare_utility(...)`
- `declare_library(...)`
- `declare_plugin(...)`
- `include_projects()`

**Detailed documentation for all parameters is located directly in the code as comments** in the `modules/api.cmake` file. The internal logic is documented in `modules/target.cmake` and `modules/deploy.cmake`.

## License

This project is distributed under the MIT License. See the [`LICENSE`](./LICENSE) file for more information.