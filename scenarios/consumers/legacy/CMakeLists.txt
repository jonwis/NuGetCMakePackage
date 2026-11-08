cmake_minimum_required(VERSION 3.31)
project(LegacyPackages LANGUAGES CXX)

include(FetchContent)
FetchContent_Declare(NuGetCMakePackage SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/../../..")
FetchContent_MakeAvailable(NuGetCMakePackage)

if(MIXED_MODE)
    if(MIXED_MODE STREQUAL "global-first")
        set(FIRST_API add_nuget_packages)
        set(SECOND_API add_target_nuget_packages)
    else()
        set(FIRST_API add_target_nuget_packages)
        set(SECOND_API add_nuget_packages)
    endif()
    foreach(API IN ITEMS "${FIRST_API}" "${SECOND_API}")
        cmake_language(CALL "${API}"
            PACKAGES Microsoft.Windows.ImplementationLibrary "1.0.0"
            CONFIG_FILE "${FIXTURE_CONFIG}"
            LOCK_FILE "${LOCK_ROOT}/${API}.packages.lock.json"
        )
    endforeach()
else()
    add_subdirectory(a)
    add_subdirectory(b)
    if(NOT TARGET Microsoft.Windows.ImplementationLibrary)
        message(FATAL_ERROR "Legacy target is not globally visible.")
    endif()
endif()
