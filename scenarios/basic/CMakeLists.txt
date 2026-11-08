cmake_minimum_required(VERSION 3.31)
project(NuGetCMakePackage.Scenarios.Basic)

include(FetchContent)

# Use the local checkout of NuGetCMakePackage rather than fetching from network.
FetchContent_Declare(
    NuGetCMakePackage
    SOURCE_DIR "${CMAKE_SOURCE_DIR}/../.."
)
FetchContent_MakeAvailable(NuGetCMakePackage)

set(SCENARIO_NUGET_CONFIG_FILE "${CMAKE_CURRENT_LIST_DIR}/nuget.config" CACHE FILEPATH "Optional scenario-only NuGet config override")

add_nuget_packages(
    PACKAGES
        Microsoft.Windows.ImplementationLibrary 1.*
        Microsoft.Windows.CppWinRT              2.0.250303.1
        Microsoft.Windows.SDK.CPP               10.0.26100.7705
    CONFIG_FILE
        "${SCENARIO_NUGET_CONFIG_FILE}"
    LOCK_FILE
        "${CMAKE_CURRENT_LIST_DIR}/packages.lock.json"
)

# ── Assertion helpers ─────────────────────────────────────────────────────────

macro(assert_variable_set VAR_NAME)
    if("${${VAR_NAME}}" STREQUAL "")
        message(FATAL_ERROR "Assertion failed: variable '${VAR_NAME}' is empty or unset.")
    endif()
endmacro()

macro(assert_path_exists PATH_EXPR LABEL)
    if(NOT EXISTS "${PATH_EXPR}")
        message(FATAL_ERROR "Assertion failed: path for '${LABEL}' does not exist: ${PATH_EXPR}")
    endif()
endmacro()

macro(assert_target_property_set TARGET PROP)
    get_target_property(_assert_prop_val ${TARGET} ${PROP})
    if("${_assert_prop_val}" MATCHES "-NOTFOUND$" OR "${_assert_prop_val}" STREQUAL "")
        message(FATAL_ERROR "Assertion failed: target '${TARGET}' property '${PROP}' is unset.")
    endif()
endmacro()

# Verify that NuNuGet was downloaded
assert_variable_set(NUNUGET_PATH)
assert_path_exists("${NUNUGET_PATH}" "NUNUGET_PATH")

# Verify that GLOBAL properties are set for all packages
foreach(_package_name IN ITEMS
    MICROSOFT_WINDOWS_IMPLEMENTATIONLIBRARY
    MICROSOFT_WINDOWS_CPPWINRT
    MICROSOFT_WINDOWS_SDK_CPP
)
    get_property(_ver GLOBAL PROPERTY "NUGET_VERSION-${_package_name}")
    get_property(_loc GLOBAL PROPERTY "NUGET_LOCATION-${_package_name}")

    if("${_ver}" STREQUAL "")
        message(FATAL_ERROR "Assertion failed: NUGET_VERSION-${_package_name} is unset.")
    endif()
    if("${_loc}" STREQUAL "")
        message(FATAL_ERROR "Assertion failed: NUGET_LOCATION-${_package_name} is unset.")
    endif()
    assert_path_exists("${_loc}" "NUGET_LOCATION-${_package_name}")
endforeach()

# Verify that Microsoft.Windows.ImplementationLibrary's floating version resolved to 1.x
get_property(_wil_version GLOBAL PROPERTY "NUGET_VERSION-MICROSOFT_WINDOWS_IMPLEMENTATIONLIBRARY")
if(NOT _wil_version MATCHES "^1\\.")
    message(FATAL_ERROR "Assertion failed: Microsoft.Windows.ImplementationLibrary floating version resolved to '${_wil_version}', expected 1.x")
endif()

# Verify that find_package variables are set
cmake_policy(GET CMP0074 _cmp0074)
cmake_policy(GET CMP0144 _cmp0144)
if(_cmp0074 STREQUAL "NEW")
    if(_cmp0144 STREQUAL "NEW")
        assert_variable_set(MICROSOFT.WINDOWS.IMPLEMENTATIONLIBRARY_ROOT)
    else()
        assert_variable_set(Microsoft.Windows.ImplementationLibrary_ROOT)
    endif()
else()
    assert_variable_set(Microsoft.Windows.ImplementationLibrary_DIR)
endif()

# Verify that find_package for Microsoft.Windows.ImplementationLibrary succeeds.
#   — the target should exist
#   — the CMake within Microsoft.Windows.ImplementationLibrary should have set the INTERFACE_INCLUDE_DIRECTORIES property
find_package(Microsoft.Windows.ImplementationLibrary CONFIG REQUIRED)

if(NOT TARGET Microsoft.Windows.ImplementationLibrary)
    message(FATAL_ERROR "Assertion failed: target 'Microsoft.Windows.ImplementationLibrary' not created by find_package.")
endif()

assert_target_property_set(Microsoft.Windows.ImplementationLibrary INTERFACE_INCLUDE_DIRECTORIES)

get_target_property(_wil_includes Microsoft.Windows.ImplementationLibrary INTERFACE_INCLUDE_DIRECTORIES)
foreach(_inc IN LISTS _wil_includes)
    assert_path_exists("${_inc}" "WIL INTERFACE_INCLUDE_DIRECTORIES")
endforeach()

message(STATUS "All scenario assertions passed.")
