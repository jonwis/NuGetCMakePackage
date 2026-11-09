cmake_minimum_required(VERSION 3.31)
project(NuGetCMakePackage.Scenarios.CppWinRTSmoke LANGUAGES CXX)

if(NOT WIN32)
    message(FATAL_ERROR "The CppWinRT smoke scenario requires Windows and an installed Windows SDK.")
endif()

include(FetchContent)
FetchContent_Declare(NuGetCMakePackage SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/../../..")
FetchContent_MakeAvailable(NuGetCMakePackage)

set(SCENARIO_NUGET_CONFIG_FILE "${CMAKE_CURRENT_LIST_DIR}/../../basic/nuget.config" CACHE FILEPATH "Optional scenario-only NuGet config override")
add_target_nuget_packages(
    PACKAGES Microsoft.Windows.CppWinRT 2.0.250303.1
    CONFIG_FILE "${SCENARIO_NUGET_CONFIG_FILE}"
    LOCK_FILE "${CMAKE_CURRENT_BINARY_DIR}/packages.lock.json"
)
find_package(Microsoft.Windows.CppWinRT CONFIG REQUIRED)

add_library(CppWinRTSmoke STATIC smoke.cpp)
target_compile_features(CppWinRTSmoke PRIVATE cxx_std_20)
target_link_libraries(CppWinRTSmoke PRIVATE Microsoft.Windows.CppWinRT)
