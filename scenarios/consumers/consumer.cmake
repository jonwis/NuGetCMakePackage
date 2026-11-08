get_filename_component(CONSUMER_NAME "${CMAKE_CURRENT_SOURCE_DIR}" NAME)
set(CONSUMER_PACKAGES
    Fixture.Native "${CONSUMER_VERSION}"
    Microsoft.Windows.ImplementationLibrary "${CONSUMER_VERSION}"
)
if(WIN32)
    list(APPEND CONSUMER_PACKAGES Microsoft.WindowsAppSDK.ML "${CONSUMER_VERSION}")
endif()

add_target_nuget_packages(
    PACKAGES ${CONSUMER_PACKAGES}
    CONFIG_FILE "${FIXTURE_CONFIG}"
    LOCK_FILE "${LOCK_ROOT}/${CONSUMER_NAME}.packages.lock.json"
)

find_package(Fixture.Native CONFIG REQUIRED)
find_package(Fixture.Dependency CONFIG REQUIRED)
find_package(Microsoft.Windows.ImplementationLibrary CONFIG REQUIRED)
if(WIN32)
    find_package(Microsoft.WindowsAppSDK.ML CONFIG REQUIRED)
endif()

foreach(PACKAGE IN ITEMS Fixture.Native Fixture.Dependency Microsoft.Windows.ImplementationLibrary)
    string(TOUPPER "${PACKAGE}" CANONICAL_NAME)
    string(REPLACE "." "_" CANONICAL_NAME "${CANONICAL_NAME}")
    get_property(RESOLVED_VERSION DIRECTORY PROPERTY "NUGET_VERSION-${CANONICAL_NAME}")
    get_property(RESOLVED_LOCATION DIRECTORY PROPERTY "NUGET_LOCATION-${CANONICAL_NAME}")
    string(TOLOWER "${PACKAGE}" PACKAGE_LOWER)
    file(TO_CMAKE_PATH "$ENV{NUGET_PACKAGES}/${PACKAGE_LOWER}/${CONSUMER_VERSION}" EXPECTED_LOCATION)
    if(NOT RESOLVED_VERSION STREQUAL CONSUMER_VERSION OR NOT RESOLVED_LOCATION STREQUAL EXPECTED_LOCATION)
        message(FATAL_ERROR "${CONSUMER_NAME}: wrong package resolution for ${PACKAGE}: ${RESOLVED_VERSION}, ${RESOLVED_LOCATION}")
    endif()
    get_target_property(INCLUDES "${PACKAGE}" INTERFACE_INCLUDE_DIRECTORIES)
    if(NOT "${EXPECTED_LOCATION}/include" IN_LIST INCLUDES)
        message(FATAL_ERROR "${CONSUMER_NAME}: wrong includes for ${PACKAGE}: ${INCLUDES}")
    endif()
    get_target_property(IS_GLOBAL "${PACKAGE}" IMPORTED_GLOBAL)
    if(IS_GLOBAL)
        message(FATAL_ERROR "${PACKAGE} is globally visible.")
    endif()
endforeach()

get_target_property(LIBRARY Fixture.Native IMPORTED_LOCATION)
get_target_property(TOOL Fixture.Native FIXTURE_TOOL)
get_property(NATIVE_LOCATION DIRECTORY PROPERTY NUGET_LOCATION-FIXTURE_NATIVE)
if(NOT LIBRARY STREQUAL "${NATIVE_LOCATION}/runtimes/win-x64/native/fixture.lib" OR NOT TOOL STREQUAL "${NATIVE_LOCATION}/tools/fixture.tool")
    message(FATAL_ERROR "${CONSUMER_NAME}: wrong native library/tool: ${LIBRARY}, ${TOOL}")
endif()

if(WIN32)
    foreach(PACKAGE IN ITEMS Microsoft.Windows.CppWinRT Microsoft.WindowsAppSDK.Foundation Microsoft.WindowsAppSDK.InteractiveExperiences Microsoft.WindowsAppSDK.ML)
        get_target_property(PROJECTION_INCLUDES "${PACKAGE}" INTERFACE_INCLUDE_DIRECTORIES)
        if(NOT PROJECTION_INCLUDES MATCHES "${CONSUMER_NAME}/__cppwinrt/")
            message(FATAL_ERROR "${CONSUMER_NAME}: projection output is not consumer-local: ${PROJECTION_INCLUDES}")
        endif()
    endforeach()
    get_target_property(CPPWINRT_LOCATION Microsoft.Windows.CppWinRT NUGET_LOCATION)
    get_target_property(CPPWINRT_TOOL Microsoft.Windows.CppWinRT CPPWINRT_EXECUTABLE_PATH)
    get_target_property(BOOTSTRAP_LIBRARY Microsoft.WindowsAppSDK.Foundation_Bootstrap IMPORTED_IMPLIB)
    if(NOT CPPWINRT_LOCATION MATCHES "/microsoft.windows.cppwinrt/${CONSUMER_VERSION}$"
        OR NOT CPPWINRT_TOOL STREQUAL "${CPPWINRT_LOCATION}/bin/cppwinrt.exe"
        OR NOT BOOTSTRAP_LIBRARY MATCHES "/microsoft.windowsappsdk.foundation/${CONSUMER_VERSION}/lib/native/.*/Microsoft.WindowsAppRuntime.Bootstrap.lib$")
        message(FATAL_ERROR "${CONSUMER_NAME}: wrong overlay tool/library locations.")
    endif()
endif()

string(REGEX MATCH "^[0-9]+" EXPECTED_VERSION "${CONSUMER_VERSION}")
add_library("Client${CONSUMER_NAME}" STATIC "${CMAKE_CURRENT_LIST_DIR}/leaf.cpp")
target_compile_features("Client${CONSUMER_NAME}" PRIVATE cxx_std_17)
target_compile_definitions("Client${CONSUMER_NAME}" PRIVATE "EXPECTED_VERSION=${EXPECTED_VERSION}")
target_link_libraries("Client${CONSUMER_NAME}" PRIVATE Microsoft.Windows.ImplementationLibrary Fixture.Native)
file(GENERATE
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/client-artifact-$<CONFIG>.txt"
    CONTENT "$<TARGET_FILE:Client${CONSUMER_NAME}>"
)

add_target_nuget_packages(
    PACKAGES ${CONSUMER_PACKAGES}
    CONFIG_FILE "${FIXTURE_CONFIG}"
    LOCK_FILE "${LOCK_ROOT}/${CONSUMER_NAME}.repeat.packages.lock.json"
)
find_package(Fixture.Native CONFIG REQUIRED)

if(SAME_CONSUMER_CONFLICT AND CONSUMER_NAME STREQUAL "a")
    add_target_nuget_packages(
        PACKAGES Fixture.Native "${VERSION_B}"
        CONFIG_FILE "${FIXTURE_CONFIG}"
        LOCK_FILE "${LOCK_ROOT}/conflict.packages.lock.json"
    )
endif()
