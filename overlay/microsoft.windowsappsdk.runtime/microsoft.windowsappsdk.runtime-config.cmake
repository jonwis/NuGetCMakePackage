#[[====================================================================================================================

    Microsoft.WindowsAppSDK.Runtime

    CMake configuration file for Microsoft.WindowsAppSDK.Runtime package.

    This package provides CMake targets:

        find_package(Microsoft.WindowsAppSDK.Runtime CONFIG REQUIRED)

        target_link_libraries(<your-target>
            PRIVATE
                Microsoft.WindowsAppSDK.Runtime
        )

    License:
        See the LICENSE file in the package root for more information.
====================================================================================================================]]#
include_guard()

# Check for minimum CMake version. Avoid using `cmake_minimum_required`, which will reset policies if this file is
# included by a project that has already specified a minimum CMake version.
if(CMAKE_VERSION VERSION_LESS 3.31)
    message(FATAL_ERROR "Microsoft.WindowsAppSDK.Runtime requires at least CMake 3.31, but CMake ${CMAKE_VERSION} is in use.")
endif()

block(SCOPE_FOR VARIABLES)
    # For 'overlay' configuration, rely on the 'NUGET_LOCATION-<package name>' global property set by the NuGetCMakePackage.
    # For 'laid out' configuration, this should rely on the location of the current file.
    get_property(PACKAGE_VERSION DIRECTORY PROPERTY NUGET_VERSION-MICROSOFT_WINDOWSAPPSDK_RUNTIME)
    set(PACKAGE_SCOPE GLOBAL)
    set(INTERFACE_SCOPE)
    if(PACKAGE_VERSION)
        set(PACKAGE_SCOPE DIRECTORY)
        set(INTERFACE_SCOPE IMPORTED)
    else()
        get_property(PACKAGE_VERSION GLOBAL PROPERTY NUGET_VERSION-MICROSOFT_WINDOWSAPPSDK_RUNTIME)
    endif()
    get_property(PACKAGE_LOCATION ${PACKAGE_SCOPE} PROPERTY NUGET_LOCATION-MICROSOFT_WINDOWSAPPSDK_RUNTIME)

    add_library(Microsoft.WindowsAppSDK.Runtime INTERFACE ${INTERFACE_SCOPE})

    target_include_directories(Microsoft.WindowsAppSDK.Runtime
        INTERFACE
            ${PACKAGE_LOCATION}/include
    )
endblock()
