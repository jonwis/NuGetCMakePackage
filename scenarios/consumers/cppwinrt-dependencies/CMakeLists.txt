cmake_minimum_required(VERSION 3.31)
project(NuGetCMakePackage.Scenarios.CppWinRTDependencies LANGUAGES NONE)

find_program(POWERSHELL_EXECUTABLE NAMES pwsh REQUIRED)

# Only the generator is mocked: the overlay's custom commands and Ninja dependencies run unchanged.
# The launcher executes the copied script at the helper's fixed bin/cppwinrt.exe path.
set_property(DIRECTORY PROPERTY RULE_LAUNCH_CUSTOM
    "\"${POWERSHELL_EXECUTABLE}\" -NoProfile -File \"${CMAKE_CURRENT_LIST_DIR}/Invoke-MockGenerator.ps1\""
)
file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/tool/bin")
configure_file(mock-cppwinrt.ps1 "${CMAKE_CURRENT_BINARY_DIR}/tool/bin/cppwinrt.exe" COPYONLY)
configure_file(input.winmd "${CMAKE_CURRENT_BINARY_DIR}/input.winmd" COPYONLY)
set_property(DIRECTORY PROPERTY NUGET_VERSION-MICROSOFT_WINDOWS_CPPWINRT "1.0.0")
set_property(DIRECTORY PROPERTY NUGET_LOCATION-MICROSOFT_WINDOWS_CPPWINRT "${CMAKE_CURRENT_BINARY_DIR}/tool")
set(CPPWINRT_SYSTEM_VERSION "${CMAKE_CURRENT_BINARY_DIR}/input.winmd")
include("${CMAKE_CURRENT_LIST_DIR}/../../../overlay/microsoft.windows.cppwinrt/microsoft.windows.cppwinrt-config.cmake")

set(reference_metadata "${CMAKE_CURRENT_BINARY_DIR}/reference.winmd")
add_custom_command(
    OUTPUT "${reference_metadata}"
    COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_CURRENT_LIST_DIR}/reference.winmd" "${reference_metadata}"
    DEPENDS "${CMAKE_CURRENT_LIST_DIR}/reference.winmd"
    VERBATIM
)
add_library(CppWinRTReferenceMetadata INTERFACE)
set_target_properties(CppWinRTReferenceMetadata PROPERTIES INTERFACE_CPPWINRT_REFS "${reference_metadata}")
add_cppwinrt_projection(CppWinRTReferenceProjection
    INPUTS "${CMAKE_CURRENT_BINARY_DIR}/input.winmd"
    DEPS CppWinRTReferenceMetadata
)
get_target_property(reference_projection CppWinRTReferenceProjection INTERFACE_INCLUDE_DIRECTORIES)
file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/reference-projection.txt" CONTENT "${reference_projection}")
add_custom_target(CppWinRTDependencies)
add_dependencies(CppWinRTDependencies CppWinRTReferenceProjection)
