cmake_minimum_required(VERSION 3.31)
project(NuGetCMakePackage.Scenarios.Framework LANGUAGES NONE)

include(FetchContent)
FetchContent_Declare(NuGetCMakePackage SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/../../..")
FetchContent_MakeAvailable(NuGetCMakePackage)

set(SCENARIO_NUGET_CONFIG_FILE "${CMAKE_CURRENT_LIST_DIR}/../nuget.config" CACHE FILEPATH "Optional scenario-only NuGet config override")
set(SCENARIO_API "add_target_nuget_packages" CACHE STRING "Package API to exercise")
set(SCENARIO_FRAMEWORK "" CACHE STRING "Optional target framework override")
option(SCENARIO_MANAGED_ONLY "Restore only the managed package" OFF)

set(packages Newtonsoft.Json "[13.0.3]")
if(NOT SCENARIO_MANAGED_ONLY)
    list(APPEND packages CLI11 "[2.2.0]")
endif()
set(framework_args)
if(NOT SCENARIO_FRAMEWORK STREQUAL "")
    list(APPEND framework_args FRAMEWORK "${SCENARIO_FRAMEWORK}")
endif()
cmake_language(CALL "${SCENARIO_API}"
    PACKAGES ${packages}
    CONFIG_FILE "${SCENARIO_NUGET_CONFIG_FILE}"
    LOCK_FILE "${SCENARIO_LOCK_FILE}"
    ${framework_args}
)

set(package_scope DIRECTORY)
if(SCENARIO_API STREQUAL "add_nuget_packages")
    set(package_scope GLOBAL)
endif()
get_property(managed_root ${package_scope} PROPERTY NUGET_LOCATION-NEWTONSOFT_JSON)
if(NOT EXISTS "${managed_root}/lib/netstandard2.0/Newtonsoft.Json.dll")
    message(FATAL_ERROR "The managed package assembly was not restored.")
endif()
if(NOT SCENARIO_MANAGED_ONLY)
    get_property(native_root ${package_scope} PROPERTY NUGET_LOCATION-CLI11)
    if(NOT EXISTS "${native_root}/lib/native/include/cli11/CLI11.hpp")
        message(FATAL_ERROR "CLI11 native headers were not restored.")
    endif()
endif()
message(STATUS "All framework scenario assertions passed.")
