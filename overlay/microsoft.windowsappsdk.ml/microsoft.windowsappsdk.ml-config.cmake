#[[====================================================================================================================

    Microsoft.WindowsAppSDK.ML

    CMake configuration file for the Microsoft.WindowsAppSDK.ML package. For consumption from a library, reference the
    'Microsoft.WindowsAppSDK.ML' library to get the Cpp/WinRT projection of the Windows ML API:

        add_nuget_packages(Microsoft.WindowsAppSDK.ML <version>)

        find_package(Microsoft.WindowsAppSDK.ML CONFIG REQUIRED)

        target_link_libraries(<your-target>
            PRIVATE
                Microsoft.WindowsAppSDK.ML
        )

    Executable projects that want to use Windows ML should reference either the 'Microsoft.WindowsAppSDK.ML_Framework'
    or 'Microsoft.WindowsAppSDK.ML_SelfContained' targets which include the necessary infrastructure to find and load
    the Windows ML runtime.

    Note: This package has a dependency on the 'Microsoft.Windows.CppWinRT' package which must also be specified in
    the consuming project.
====================================================================================================================]]#
include_guard()

# Check for minimum CMake version. Avoid using `cmake_minimum_required`, which will reset policies if this file is
# included by a project that has already specified a minimum CMake version.
if(CMAKE_VERSION VERSION_LESS 3.31)
    message(FATAL_ERROR "Microsoft.WindowsAppSDK.ML requires at least CMake 3.31, but CMake ${CMAKE_VERSION} is in use.")
endif()

find_package(Microsoft.Windows.CppWinRT CONFIG REQUIRED)
find_package(Microsoft.WindowsAppSDK.Runtime CONFIG REQUIRED)
find_package(Microsoft.WindowsAppSDK.Foundation CONFIG REQUIRED)
find_package(Microsoft.WindowsAppSDK.InteractiveExperiences CONFIG REQUIRED)

if(NOT (TARGET Microsoft.Windows.CppWinRT))
    message(FATAL_ERROR "Microsoft.Windows.CppWinRT not found. Ensure that the Microsoft.Windows.CppWinRT dependency is correctly specified.")
endif()

block(SCOPE_FOR VARIABLES)
    # Set the 'PLATFORM_IDENTIFIER' - mapping CMake constructs to the identifiers that the NuGet package layout uses.
    if(CMAKE_GENERATOR MATCHES "^Visual Studio")
        set(PLATFORM_IDENTIFIER ${CMAKE_GENERATOR_PLATFORM})
    else()
        set(PLATFORM_PROCESSOR ${CMAKE_SYSTEM_PROCESSOR})
        if(PLATFORM_PROCESSOR STREQUAL "")
            set(PLATFORM_PROCESSOR ${CMAKE_HOST_PROCESSOR})
        endif()
        if(PLATFORM_PROCESSOR STREQUAL "AMD64")
            set(PLATFORM_IDENTIFIER "x64")
        elseif(PLATFORM_PROCESSOR STREQUAL "ARM64")
            set(PLATFORM_IDENTIFIER "arm64")
        endif()
    endif()

    if(PLATFORM_IDENTIFIER STREQUAL "")
        message(FATAL_ERROR "Unable to determine the platform identifier.")
    endif()

    # For 'overlay' configuration, rely on the 'NUGET_LOCATION-<package name>' global property set by the NuGetCMakePackage.
    # For 'laid out' configuration, this should rely on the location of the current file.
    get_property(PACKAGE_VERSION DIRECTORY PROPERTY NUGET_VERSION-MICROSOFT_WINDOWSAPPSDK_ML)
    set(PACKAGE_SCOPE GLOBAL)
    set(INTERFACE_SCOPE)
    set(IMPORTED_SCOPE GLOBAL)
    if(PACKAGE_VERSION)
        set(PACKAGE_SCOPE DIRECTORY)
        set(INTERFACE_SCOPE IMPORTED)
        set(IMPORTED_SCOPE)
    else()
        get_property(PACKAGE_VERSION GLOBAL PROPERTY NUGET_VERSION-MICROSOFT_WINDOWSAPPSDK_ML)
    endif()
    get_property(PACKAGE_LOCATION ${PACKAGE_SCOPE} PROPERTY NUGET_LOCATION-MICROSOFT_WINDOWSAPPSDK_ML)

    #[[====================================================================================================================
        Target: Microsoft.WindowsAppSDK.ML

        The Cpp/WinRT projection for the Windows AI Machine Learning WinMD.
    ====================================================================================================================]]#
    add_cppwinrt_projection(Microsoft.WindowsAppSDK.ML
        INPUTS
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.AI.MachineLearning.winmd
        OPTIMIZE
        DEPS
            Microsoft.Windows.CppWinRT
    )

    target_include_directories(Microsoft.WindowsAppSDK.ML
        INTERFACE
            ${PACKAGE_LOCATION}/include
    )

    #[[====================================================================================================================
        Target: Microsoft.WindowsAppSDK.ML_Framework
        The target for the framework dependencies of the Windows AI Machine Learning library.
    ====================================================================================================================]]#
    add_library(Microsoft.WindowsAppSDK.ML_Framework INTERFACE ${INTERFACE_SCOPE})

    target_compile_definitions(Microsoft.WindowsAppSDK.ML_Framework
        INTERFACE
            ORT_API_MANUAL_INIT
    )

    target_include_directories(Microsoft.WindowsAppSDK.ML_Framework
        INTERFACE
            ${CMAKE_CURRENT_LIST_DIR}/Stub
    )

    target_sources(Microsoft.WindowsAppSDK.ML_Framework
        INTERFACE
            ${PACKAGE_LOCATION}/include/WindowsMLAutoInitializer.cpp
            ${CMAKE_CURRENT_LIST_DIR}/Stub/winml/Runtime.cpp
    )

    target_link_libraries(Microsoft.WindowsAppSDK.ML_Framework
        INTERFACE
            Microsoft.WindowsAppSDK.ML
            Microsoft.WindowsAppSDK.Runtime
            onecoreuap.lib
    )

    #[[====================================================================================================================
    ====================================================================================================================]]#

    add_library(Microsoft.WindowsAppSDK.ML_SelfContainedRuntime SHARED IMPORTED ${IMPORTED_SCOPE})

    set(FRAMEWORK_PATH "${PACKAGE_LOCATION}/runtimes-framework/win-${PLATFORM_IDENTIFIER}/native")
    set(FRAMEWORK_DLLS
        "${FRAMEWORK_PATH}/onnxruntime.dll"
        "${FRAMEWORK_PATH}/onnxruntime_providers_shared.dll"
        "${FRAMEWORK_PATH}/DirectML.dll"
        "${FRAMEWORK_PATH}/Microsoft.Windows.AI.MachineLearning.dll"
    )

    if(PACKAGE_VERSION VERSION_GREATER_EQUAL "1.8.2109")
        set_target_properties(Microsoft.WindowsAppSDK.ML_SelfContainedRuntime
            PROPERTIES
                IMPORTED_IMPLIB     "${PACKAGE_LOCATION}/lib/native/${PLATFORM_IDENTIFIER}/onnxruntime.lib"
                IMPORTED_LOCATION   "${FRAMEWORK_DLLS}"
        )
    else()
        set_target_properties(Microsoft.WindowsAppSDK.ML_SelfContainedRuntime
            PROPERTIES
                IMPORTED_IMPLIB     "${PACKAGE_LOCATION}/runtimes/win-${PLATFORM_IDENTIFIER}/native/onnxruntime.lib"
                IMPORTED_LOCATION   "${FRAMEWORK_DLLS}"
        )
    endif()

    #[[====================================================================================================================
        Target: Microsoft.WindowsAppSDK.ML_SelfContained

        The target for the 'self-contained' dependencies of the Windows AI Machine Learning library.
    ====================================================================================================================]]#
    add_library(Microsoft.WindowsAppSDK.ML_SelfContained INTERFACE ${INTERFACE_SCOPE})

    target_sources(Microsoft.WindowsAppSDK.ML_SelfContained
        INTERFACE
            ${CMAKE_CURRENT_LIST_DIR}/microsoft.windowsappsdk.ml.manifest
            ${PACKAGE_LOCATION}/include/WindowsMLAutoInitializer.SelfContained.cpp
    )

    target_link_options(Microsoft.WindowsAppSDK.ML_SelfContained
        INTERFACE
            /MANIFEST
    )

    target_link_libraries(Microsoft.WindowsAppSDK.ML_SelfContained
        INTERFACE
            Microsoft.WindowsAppSDK.ML
            Microsoft.WindowsAppSDK.ML_SelfContainedRuntime

            Microsoft.WindowsAppSDK.Runtime
            Microsoft.WindowsAppSDK.Foundation_SelfContained
            Microsoft.WindowsAppSDK.InteractiveExperiences_SelfContained
    )
endblock()
