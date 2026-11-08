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

file(TO_CMAKE_PATH "$ENV{WindowsSdkDir}/UnionMetadata/$ENV{WindowsSDKVersion}/Windows.winmd" sdk_metadata)
set(reference_metadata "${CMAKE_CURRENT_BINARY_DIR}/reference.winmd")
add_custom_command(
    OUTPUT "${reference_metadata}"
    COMMAND "${CMAKE_COMMAND}" -E copy "${sdk_metadata}" "${reference_metadata}"
    DEPENDS "${sdk_metadata}"
    VERBATIM
)
add_library(CppWinRTReferenceMetadata INTERFACE)
set_target_properties(CppWinRTReferenceMetadata PROPERTIES INTERFACE_CPPWINRT_REFS "${reference_metadata}")
get_target_property(package_root Microsoft.Windows.CppWinRT NUGET_LOCATION)
file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/tool/bin")
configure_file("${package_root}/bin/cppwinrt.exe" "${CMAKE_CURRENT_BINARY_DIR}/tool/bin/cppwinrt.exe" COPYONLY)
set_target_properties(Microsoft.Windows.CppWinRT PROPERTIES NUGET_LOCATION "${CMAKE_CURRENT_BINARY_DIR}/tool")
add_cppwinrt_projection(CppWinRTReferenceProjection INPUTS sdk DEPS CppWinRTReferenceMetadata)
get_target_property(reference_projection CppWinRTReferenceProjection INTERFACE_INCLUDE_DIRECTORIES)
file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/reference-projection.txt" CONTENT "${reference_projection}")

add_library(CppWinRTSmoke STATIC smoke.cpp)
target_compile_features(CppWinRTSmoke PRIVATE cxx_std_20)
target_link_libraries(CppWinRTSmoke PRIVATE Microsoft.Windows.CppWinRT CppWinRTReferenceProjection)
