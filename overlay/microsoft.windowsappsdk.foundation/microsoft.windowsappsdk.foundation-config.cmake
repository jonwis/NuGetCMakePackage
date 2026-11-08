#[[====================================================================================================================

    Microsoft.WindowsAppSDK.Foundation

    CMake configuration file for Microsoft.WindowsAppSDK.Foundation package. Use `find_package(Microsoft.WindowsAppSDK.Foundation CONFIG...)`
    to load this package and its dependencies:

        find_package(Microsoft.WindowsAppSDK.Foundation CONFIG REQUIRED)

    This package defines the following CMake targets:

        * Microsoft.WindowsAppSDK.Foundation - A target representing the Cpp/WinRT projection, headers and libraries of
            the Windows App SDK Foundation APIs. This does not include the necessary runtime components to use the
            Windows App SDK, and is intended to be used by library authors who want to consume the Windows App SDK
            Foundation APIs.

        * Microsoft.WindowsAppSDK.Foundation_Framework - A target representing the Windows App SDK Foundation APIs that
            also takes a dependency on the 'Framework Package' of the Windows App SDK. Target properties can be set on
            _consuming_ target to control:
                * `WindowsAppSdkBootstrapInitialize` - Whether to automatically initialize the Framework Package via
                    the 'dynamic dependency' bootstrap logic.
                * `WindowsAppSdkDeploymentManagerInitialize` - Whether to automatically initialize the Deployment
                    Manager bootstrap logic.

        * Microsoft.WindowsAppSDK.Foundation_SelfContained - An interface target that represents the Windows App SDK
            Foundation APIs for self-contained deployment scenarios. Projects should normally link against this target,
            which in turn depends on `Microsoft.WindowsAppSDK.Foundation_SelfContainedRuntime` to provide the required
            implementation dependencies of the Windows App SDK.

    License:
        See the LICENSE file in the package root for more information.
====================================================================================================================]]#
include_guard()

# Check for minimum CMake version. Avoid using `cmake_minimum_required`, which will reset policies if this file is
# included by a project that has already specified a minimum CMake version.
if(CMAKE_VERSION VERSION_LESS 3.31)
    message(FATAL_ERROR "Microsoft.WindowsAppSDK.Foundation requires at least CMake 3.31, but CMake ${CMAKE_VERSION} is in use.")
endif()

find_package(Microsoft.Windows.CppWinRT CONFIG REQUIRED)
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
    get_property(PACKAGE_VERSION DIRECTORY PROPERTY NUGET_VERSION-MICROSOFT_WINDOWSAPPSDK_FOUNDATION)
    set(PACKAGE_SCOPE GLOBAL)
    set(INTERFACE_SCOPE)
    set(IMPORTED_SCOPE GLOBAL)
    if(PACKAGE_VERSION)
        set(PACKAGE_SCOPE DIRECTORY)
        set(INTERFACE_SCOPE IMPORTED)
        set(IMPORTED_SCOPE)
    else()
        get_property(PACKAGE_VERSION GLOBAL PROPERTY NUGET_VERSION-MICROSOFT_WINDOWSAPPSDK_FOUNDATION)
    endif()
    get_property(PACKAGE_LOCATION ${PACKAGE_SCOPE} PROPERTY NUGET_LOCATION-MICROSOFT_WINDOWSAPPSDK_FOUNDATION)

    #[[====================================================================================================================
        Target: Microsoft.WindowsAppSDK.Foundation
    ====================================================================================================================]]#
    add_cppwinrt_projection(Microsoft.WindowsAppSDK.Foundation
        INPUTS
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.ApplicationModel.Background.UniversalBGTask.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.ApplicationModel.Background.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.ApplicationModel.DynamicDependency.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.ApplicationModel.Resources.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.ApplicationModel.WindowsAppRuntime.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.AppLifecycle.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.AppNotifications.Builder.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.AppNotifications.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.BadgeNotifications.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.Foundation.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.Globalization.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.Management.Deployment.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.Media.Capture.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.PushNotifications.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.Security.AccessControl.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.Storage.Pickers.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.Storage.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.System.Power.winmd
            ${PACKAGE_LOCATION}/metadata/Microsoft.Windows.System.winmd
        OPTIMIZE
        DEPS
            Microsoft.WindowsAppSDK.InteractiveExperiences
    )

    target_include_directories(Microsoft.WindowsAppSDK.Foundation
        INTERFACE
            ${PACKAGE_LOCATION}/include
    )

    #[[====================================================================================================================
        Target: Microsoft.WindowsAppSDK.Foundation_Framework
    ====================================================================================================================]]#
    add_library(Microsoft.WindowsAppSDK.Foundation_Framework INTERFACE ${INTERFACE_SCOPE})

    target_link_libraries(Microsoft.WindowsAppSDK.Foundation_Framework
        INTERFACE
            Microsoft.WindowsAppSDK.Foundation
    )

    #[[====================================================================================================================
        Targets:
            Microsoft.WindowsAppSDK.Foundation_Bootstrap
            Microsoft.WindowsAppSDK.Foundation_DynamicDependencyBootstrap
            Microsoft.WindowsAppSDK.Foundation_DeploymentManagerBootstrap

        Note: Consumers should not consume these targets directly. Instead, consume 'Microsoft.WindowsAppSDK.Foundation_Framework'
        and set target properties on the _consuming_ target.

        These targets need the Microsoft.WindowsAppSDK.Runtime package to be present. If the package cannot be found,
        these targets will not be created, and the end-user will need to bootstrap the Framework manually.
    ====================================================================================================================]]#
    find_package(Microsoft.WindowsAppSDK.Runtime CONFIG QUIET)
    if(NOT Microsoft.WindowsAppSDK.Runtime_FOUND)
        message(VERBOSE "Microsoft.WindowsAppSDK.Runtime *not* found. The 'bootstrap' logic will *not* be available, and the Framework will need to be bootstrapped manually.")
    else()
        add_library(Microsoft.WindowsAppSDK.Foundation_Bootstrap SHARED IMPORTED ${IMPORTED_SCOPE})

        target_sources(Microsoft.WindowsAppSDK.Foundation_Bootstrap
            INTERFACE
                "${PACKAGE_LOCATION}/include/WindowsAppRuntimeAutoInitializer.cpp"
        )

        set_target_properties(Microsoft.WindowsAppSDK.Foundation_Bootstrap
            PROPERTIES
                IMPORTED_IMPLIB "${PACKAGE_LOCATION}/lib/native/${PLATFORM_IDENTIFIER}/Microsoft.WindowsAppRuntime.Bootstrap.lib"
                IMPORTED_LOCATION "${PACKAGE_LOCATION}/runtimes/win-${PLATFORM_IDENTIFIER}/native/Microsoft.WindowsAppRuntime.Bootstrap.dll"
        )

        target_link_libraries(Microsoft.WindowsAppSDK.Foundation_Bootstrap
            INTERFACE
                Microsoft.WindowsAppSDK.Runtime
        )

        # The 'Microsoft.WindowsAppSDK.Foundation_DynamicDependencyBootstrap' target adds the
        # 'MddBootstrapAutoInitializer.cpp' source, and the MICROSOFT_WINDOWSAPPSDK_AUTOINITIALIZE_BOOTSTRAP
        # preprocessor definition.
        add_library(Microsoft.WindowsAppSDK.Foundation_DynamicDependencyBootstrap INTERFACE ${INTERFACE_SCOPE})

        target_sources(Microsoft.WindowsAppSDK.Foundation_DynamicDependencyBootstrap
            INTERFACE
                "${PACKAGE_LOCATION}/include/MddBootstrapAutoInitializer.cpp"
        )

        target_compile_definitions(Microsoft.WindowsAppSDK.Foundation_DynamicDependencyBootstrap
            INTERFACE
                MICROSOFT_WINDOWSAPPSDK_AUTOINITIALIZE_BOOTSTRAP
        )

        target_link_libraries(Microsoft.WindowsAppSDK.Foundation_DynamicDependencyBootstrap
            INTERFACE
                Microsoft.WindowsAppSDK.Foundation_Bootstrap
        )

        # The 'Microsoft.WindowsAppSDK.Foundation_DeploymentManagerBootstrap' target adds the
        # 'DeploymentManagerAutoInitializer.cpp' source, and the MICROSOFT_WINDOWSAPPSDK_AUTOINITIALIZE_DEPLOYMENTMANAGER
        # preprocessor definition.
        add_library(Microsoft.WindowsAppSDK.Foundation_DeploymentManagerBootstrap INTERFACE ${INTERFACE_SCOPE})

        target_sources(Microsoft.WindowsAppSDK.Foundation_DeploymentManagerBootstrap
            INTERFACE
                "${PACKAGE_LOCATION}/include/DeploymentManagerAutoInitializer.cpp"
        )

        target_compile_definitions(Microsoft.WindowsAppSDK.Foundation_DeploymentManagerBootstrap
            INTERFACE
                MICROSOFT_WINDOWSAPPSDK_AUTOINITIALIZE_DEPLOYMENTMANAGER
        )

        target_link_libraries(Microsoft.WindowsAppSDK.Foundation_DeploymentManagerBootstrap
            INTERFACE
                Microsoft.WindowsAppSDK.Foundation_Bootstrap
        )

        # 'Microsoft.WindowsAppSDK.Foundation_Framework' should now depend on the individual bootstrap targets,
        # conditional on properties of the consuming target.
        target_link_libraries(Microsoft.WindowsAppSDK.Foundation_Framework
            INTERFACE
                $<$<BOOL:$<TARGET_PROPERTY:WindowsAppSdkBootstrapInitialize>>:Microsoft.WindowsAppSDK.Foundation_DynamicDependencyBootstrap>
                $<$<BOOL:$<TARGET_PROPERTY:WindowsAppSdkDeploymentManagerInitialize>>:Microsoft.WindowsAppSDK.Foundation_DeploymentManagerBootstrap>
        )
    endif()

    #[[====================================================================================================================
        Target: Microsoft.WindowsAppSDK.Foundation_SelfContained
    ====================================================================================================================]]#
    add_library(Microsoft.WindowsAppSDK.Foundation_SelfContainedRuntime SHARED IMPORTED ${IMPORTED_SCOPE})

    set(FRAMEWORK_PATH "${PACKAGE_LOCATION}/runtimes-framework/win-${PLATFORM_IDENTIFIER}/native")
    set(FRAMEWORK_DLLS
        "${FRAMEWORK_PATH}/Microsoft.Windows.ApplicationModel.Resources.dll"
        "${FRAMEWORK_PATH}/Microsoft.WindowsAppRuntime.dll"
    )

    set_target_properties(Microsoft.WindowsAppSDK.Foundation_SelfContainedRuntime
        PROPERTIES
            IMPORTED_IMPLIB "${PACKAGE_LOCATION}/lib/native/${PLATFORM_IDENTIFIER}/Microsoft.WindowsAppRuntime.lib"
            IMPORTED_LOCATION "${FRAMEWORK_DLLS}"
    )

    add_library(Microsoft.WindowsAppSDK.Foundation_SelfContained INTERFACE ${INTERFACE_SCOPE})

    target_sources(Microsoft.WindowsAppSDK.Foundation_SelfContained
        INTERFACE
            ${CMAKE_CURRENT_LIST_DIR}/Microsoft.WindowsAppSDK.Foundation.manifest
    )

    target_link_options(Microsoft.WindowsAppSDK.Foundation_SelfContained
        INTERFACE
            /MANIFEST
    )

    target_link_libraries(Microsoft.WindowsAppSDK.Foundation_SelfContained
        INTERFACE
            Microsoft.WindowsAppSDK.Foundation
            Microsoft.WindowsAppSDK.Foundation_SelfContainedRuntime
    )

endblock()
