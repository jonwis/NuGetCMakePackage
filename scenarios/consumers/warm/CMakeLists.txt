cmake_minimum_required(VERSION 3.31)
project(WarmRestore LANGUAGES NONE)

include(FetchContent)
FetchContent_Declare(NuGetCMakePackage SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/../../..")
FetchContent_MakeAvailable(NuGetCMakePackage)

set(FIXTURE_VERSION "1.0.0" CACHE STRING "Fixture package version")
set(PACKAGE_API add_target_nuget_packages)
if(TEST_LEGACY)
    set(PACKAGE_API add_nuget_packages)
endif()
cmake_language(CALL "${PACKAGE_API}"
    PACKAGES Fixture.Native "${FIXTURE_VERSION}"
    CONFIG_FILE "${FIXTURE_CONFIG}"
    LOCK_FILE "${LOCK_ROOT}/packages.lock.json"
)
find_package(Fixture.Native CONFIG REQUIRED)
find_package(Fixture.Dependency CONFIG REQUIRED)
foreach(PACKAGE IN ITEMS Fixture.Native Fixture.Dependency)
    string(TOLOWER "${PACKAGE}" ID)
    file(TO_CMAKE_PATH "$ENV{NUGET_PACKAGES}/${ID}/${FIXTURE_VERSION}/include" EXPECTED_INCLUDE)
    get_target_property(INCLUDES "${PACKAGE}" INTERFACE_INCLUDE_DIRECTORIES)
    if(NOT EXPECTED_INCLUDE IN_LIST INCLUDES)
        message(FATAL_ERROR "Wrong cache location for ${PACKAGE}: ${INCLUDES}")
    endif()
endforeach()

if(SECOND_VERSION)
    add_target_nuget_packages(
        PACKAGES Fixture.Native "${SECOND_VERSION}"
        CONFIG_FILE "${FIXTURE_CONFIG}"
        LOCK_FILE "${LOCK_ROOT}/second.packages.lock.json"
    )
endif()
