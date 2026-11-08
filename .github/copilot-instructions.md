# Copilot Instructions for NuGetCMakePackage

## Overview

This is a CMake module that integrates NuGet package management into CMake builds. Consumers include it via `FetchContent` and call `add_nuget_packages()` to download NuGet packages and make them discoverable through `find_package()`. The module uses the [NuNuGet](https://github.com/mschofie/NuNuGet) tool for package resolution.

## Building and Testing

This project has no standalone build — it is a CMake module consumed by other projects via `FetchContent_MakeAvailable`.

### Running tests

Tests use **Pester v5** (PowerShell). The scenario tests exercise the full NuGet-to-CMake pipeline:

```powershell
# Run all scenario tests
Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck -Scope CurrentUser
Invoke-Pester scenarios/basic/Basic.Tests.ps1 -Output Detailed

# Run a single test by name
Invoke-Pester scenarios/basic/Basic.Tests.ps1 -Output Detailed -Filter @{ FullName = '*lock file*' }
```

The scenario tests configure a real CMake project under `__build/scenario-basic/`, download NuNuGet and NuGet packages, and verify lock file generation and consistency.

### CI

GitHub Actions runs scenario tests on Windows, Ubuntu, and macOS via `.github/workflows/scenario-tests.yml`.

## Architecture

### Core flow

1. Consumer calls `add_nuget_packages(PACKAGES ... CONFIG_FILE ... LOCK_FILE ...)`
2. Package list is templated into JSON via `packages.list.json.in`
3. NuNuGet is located or auto-downloaded (to `__tools/`) and invoked to resolve packages
4. Resolved packages are parsed from NuNuGet output; global properties are set:
   - `NUGET_VERSION-<CANONICAL_NAME>` and `NUGET_LOCATION-<CANONICAL_NAME>`
5. CMake entry points are probed in the package and in `:/overlay/` ('overlay' configs)
6. Discovery variables (`*_ROOT` or `*_DIR`) are set so `find_package()` works

### Overlay config files (`:/overlay/`)

When a NuGet package doesn't ship its own CMake config, this repo provides overlay configs under `:/overlay/<package-name-lowercase>/<package-name-lowercase>-config.cmake`. These files:

- Start with `include_guard()` and a CMake ≥ 3.31 version check (using `CMAKE_VERSION`, **not** `cmake_minimum_required`, to avoid resetting policies)
- Retrieve package location and version from global properties set by `add_nuget_packages()`
- Create `IMPORTED` or `INTERFACE` library targets with appropriate include dirs, link libraries, and DLLs
- Support both "overlay" mode (config provided by this repo) and "laid out" mode (config bundled in the NuGet)

### Canonical package name conversion

NuGet package names are converted to CMake property names by uppercasing and replacing `.` and `-` with `_`. Example: `Microsoft.Windows.CppWinRT` → `MICROSOFT_WINDOWS_CPPWINRT`.

## Key Conventions

### CMake version and policy handling

- Minimum CMake version is **3.31**. Includable files check `CMAKE_VERSION VERSION_LESS 3.31` instead of calling `cmake_minimum_required()` to avoid resetting the caller's policies.
- Functions using `cmake_parse_arguments(PARSE_ARGV ...)` wrap in `block(SCOPE_FOR POLICIES)` with `cmake_policy(SET CMP0174 NEW)`.
- Policy `CMP0074` (package root variables) and    `CMP0144` (case-sensitive root variables) determine whether `*_ROOT` or `*_DIR` is set.

###

 File structure

- `__*` directories (e.g., `__build/`, `__tools/`, `__nuget-packages/`) are transient/generated and gitignored.
- 'Overlay' config files live at `:/overlay/<package-name-lowercase>/<package-name-lowercase>-config.cmake`.
- Each overlay config follows the same template: include guard → version check → retrieve global properties → create targets.

### Testing patterns

- Scenario tests live under(scenarios/<name>/) with a Pester script, a `CMakeLists.txt`, and a `nuget.config`.
- CMake-level assertions use custom macros: `assert_variable_set()`, `assert_path_exists()`, `assert_target_property_set()`.
- Tests run a two-step CMake configure: first to generate the lock file, second to verify lock file consistency.

### Code style

- UTF-8, 4-space indentation, no trailing whitespace, final newline (see `.editorconfig`).
