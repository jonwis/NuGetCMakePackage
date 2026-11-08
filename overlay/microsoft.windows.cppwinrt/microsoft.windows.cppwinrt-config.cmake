#[[====================================================================================================================

    Microsoft.Windows.CppWinRT
    --------------------------
    CMake configuration file for the Microsoft.Windows.CppWinRT package.

        add_nuget_packages(Microsoft.Windows.CppWinRT <version>)

        find_package(Microsoft.Windows.CppWinRT CONFIG REQUIRED)

        target_link_libraries(<your-target>
            PRIVATE
                Microsoft.Windows.CppWinRT
        )

    The 'Microsoft.Windows.CppWinRT' target represents the CppWinRT projection for the system version being targeted.

====================================================================================================================]]#
include_guard()

# Check for minimum CMake version. Avoid using `cmake_minimum_required`, which will reset policies if this file is
# included by a project that has already specified a minimum CMake version.
if(CMAKE_VERSION VERSION_LESS 3.31)
    message(FATAL_ERROR "Microsoft.Windows.CppWinRT requires at least CMake 3.31, but CMake ${CMAKE_VERSION} is in use.")
endif()

#[[====================================================================================================================
    add_cppwinrt_projection
    -----------------------

    Creates a target representing a C++/WinRT projection

        add_cppwinrt_projection(<target>
            INPUTS <spec>+
            [DEPS <spec>+]
            [PROJECTION_ROOT_PATH <path>]
            [OPTIMIZE]
        )

    The 'INPUTS' will be used to generate the projection, and can be of the form:
        * any value accepted by the cppwinrt tooling:
            * path                Path to winmd file or recursively scanned folder
            * local               Local %WinDir%\System32\WinMetadata folder
            * sdk[+]              Current version of Windows SDK [with extensions]
            * 10.0.12345.0[+]     Specific version of Windows SDK [with extensions]

    If the INPUTS includes a path to a .winmd file, the file will be a dependency of the target that generates the
    projection.

    The DEPS parameter is optional, but may contain target names of dependencies. These will be added to the
    target_link_libraries of this projection target, and any referenced cppwinrt inputs will be used for the
    -ref parameter to cppwinrt when generating this target's projection.

    The PROJECTION_ROOT_PATH is optional. If not specified, and CPPWINRT_PROJECTION_ROOT_PATH is set, then the value of
    CPPWINRT_PROJECTION_ROOT_PATH will be used. If no value for PROJECTION_ROOT_PATH is specified, it will be defaulted
    to `${CMAKE_BINARY_DIR}/__cppwinrt`. Note: It is recommended that a custom value is specified outside of
    ${CMAKE_BINARY_DIR}, so that the same generated projection files can be used for all platforms and configurations.

    Opt-in mode defaults to `${CMAKE_CURRENT_BINARY_DIR}/__cppwinrt` and adds a consumer/target suffix.

====================================================================================================================]]#
function(add_cppwinrt_projection TARGET_NAME)
    set(OPTIONS OPTIMIZE)
    set(ONE_VALUE_KEYWORDS PROJECTION_ROOT_PATH PCH_NAME)
    set(MULTI_VALUE_KEYWORDS INPUTS DEPS)

    if(NOT TARGET_NAME)
        message(FATAL_ERROR "add_cppwinrt_projection called with incorrect arguments: a target name is required.")
    endif()

    get_property(SCOPED_VERSION DIRECTORY PROPERTY NUGET_VERSION-MICROSOFT_WINDOWS_CPPWINRT)
    set(DIRECTORY_SCOPED FALSE)
    if(SCOPED_VERSION)
        set(DIRECTORY_SCOPED TRUE)
    elseif(TARGET Microsoft.Windows.CppWinRT)
        get_target_property(DIRECTORY_SCOPED Microsoft.Windows.CppWinRT NUGET_DIRECTORY_SCOPED)
    endif()
    if(DIRECTORY_SCOPED AND TARGET "${TARGET_NAME}")
        message(FATAL_ERROR "add_cppwinrt_projection: Target '${TARGET_NAME}' is already visible in this consumer. Use a distinct projection target name.")
    endif()

    cmake_parse_arguments(PARSE_ARGV 1 CPPWINRT "${OPTIONS}" "${ONE_VALUE_KEYWORDS}" "${MULTI_VALUE_KEYWORDS}")

    if(NOT CPPWINRT_PROJECTION_ROOT_PATH)
        if(DIRECTORY_SCOPED)
            set(CPPWINRT_PROJECTION_ROOT_PATH ${CMAKE_CURRENT_BINARY_DIR}/__cppwinrt)
        else()
            set(CPPWINRT_PROJECTION_ROOT_PATH ${CMAKE_BINARY_DIR}/__cppwinrt)
        endif()
    endif()

    set(CPPWINRT_REFS)
    if(CPPWINRT_DEPS)
        foreach(_dep IN LISTS CPPWINRT_DEPS)
            get_target_property(_refs ${_dep} INTERFACE_CPPWINRT_REFS)
            if (NOT _refs MATCHES "-NOTFOUND$")
                list(APPEND CPPWINRT_REFS ${_refs})
            else()
                message(WARNING "add_cppwinrt_project: Dependency ${_dep} does not have target property INTERFACE_CPPWINRT_REFS!")
            endif()
        endforeach()
    endif()

    message(VERBOSE "add_cppwinrt_projection: CPPWINRT_PROJECTION_ROOT_PATH = ${CPPWINRT_PROJECTION_ROOT_PATH}")

    # For 'overlay' configuration, rely on the 'NUGET_LOCATION-<package name>' global property set by the NuGetCMakePackage.
    # For 'laid out' configuration, this should rely on the location of the current file.
    if(DIRECTORY_SCOPED)
        if(TARGET Microsoft.Windows.CppWinRT)
            get_target_property(PACKAGE_LOCATION Microsoft.Windows.CppWinRT NUGET_LOCATION)
            get_target_property(PACKAGE_VERSION Microsoft.Windows.CppWinRT NUGET_VERSION)
        else()
            get_property(PACKAGE_LOCATION DIRECTORY PROPERTY NUGET_LOCATION-MICROSOFT_WINDOWS_CPPWINRT)
            get_property(PACKAGE_VERSION DIRECTORY PROPERTY NUGET_VERSION-MICROSOFT_WINDOWS_CPPWINRT)
        endif()
    else()
        get_property(PACKAGE_LOCATION GLOBAL PROPERTY NUGET_LOCATION-MICROSOFT_WINDOWS_CPPWINRT)
    endif()

    # Build the command to generate the projection
    set(CPPWINRT_OUTPUT ${CPPWINRT_PROJECTION_ROOT_PATH}/${TARGET_NAME})
    if(DIRECTORY_SCOPED)
        string(SHA256 PROJECTION_ID "${CMAKE_CURRENT_BINARY_DIR}|${TARGET_NAME}")
        string(SUBSTRING "${PROJECTION_ID}" 0 16 PROJECTION_ID)
        set(PROJECTION_TARGET "_nuget_cppwinrt_${PROJECTION_ID}")
        string(APPEND CPPWINRT_OUTPUT "/${PROJECTION_ID}")
        file(MAKE_DIRECTORY "${CPPWINRT_OUTPUT}")
    endif()
    set(CPPWINRT_OUTPUT_FILE ${CPPWINRT_OUTPUT}/output.log)
    set(CPPWINRT_EXECUTABLE_PATH ${PACKAGE_LOCATION}/bin/cppwinrt.exe)

    set(CPPWINRT_COMMAND)
    list(APPEND CPPWINRT_COMMAND
        ${CPPWINRT_EXECUTABLE_PATH}
        -output ${CPPWINRT_OUTPUT}
        -input ${CPPWINRT_INPUTS}
        -ref ${CPPWINRT_REFS}
    )

    if(CPPWINRT_OPTIMIZE)
        list(APPEND CPPWINRT_COMMAND -optimize)
    endif()

    list(APPEND CPPWINRT_COMMAND > ${CPPWINRT_OUTPUT_FILE})

    # Check input and reference metadata, if the items are none of:
    #   * local
    #   * sdk[+]
    #   * 10.0.12345.0[+]
    # add it as a dependency. If the item is a folder, add the recursively glob'd '*.winmd' files as dependencies.
    set(CPPWINRT_DEPENDS)
    foreach(CPPWINRT_INPUT IN LISTS CPPWINRT_INPUTS CPPWINRT_REFS)
        if((CPPWINRT_INPUT STREQUAL "local") OR
            (CPPWINRT_INPUT MATCHES [[^sdk\+?$]]) OR
            (CPPWINRT_INPUT MATCHES [[^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\+?$]]))
            message(VERBOSE "add_cppwinrt_projection: CPPWINRT_INPUT = ${CPPWINRT_INPUT}")
            continue()
        endif()

        if(IS_DIRECTORY "${CPPWINRT_INPUT}")
            file(GLOB_RECURSE CPPWINRT_INPUT_GLOB "${CPPWINRT_INPUT}/*.winmd")
            message(VERBOSE "add_cppwinrt_projection: CPPWINRT_INPUT = ${CPPWINRT_INPUT_GLOB} (dependency)")
            list(APPEND CPPWINRT_DEPENDS ${CPPWINRT_INPUT_GLOB})
            continue()
        endif()

        message(VERBOSE "add_cppwinrt_projection: CPPWINRT_INPUT = ${CPPWINRT_INPUT} (dependency)")
        list(APPEND CPPWINRT_DEPENDS ${CPPWINRT_INPUT})
    endforeach()

    add_custom_command(
        OUTPUT ${CPPWINRT_OUTPUT_FILE}
        COMMAND ${CPPWINRT_COMMAND}
        DEPENDS ${CPPWINRT_DEPENDS} "${CPPWINRT_EXECUTABLE_PATH}"
        COMMENT "Generating C++/WinRT Projection - ${TARGET_NAME}"
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    )

    if(DIRECTORY_SCOPED)
        add_custom_target(${PROJECTION_TARGET} DEPENDS "${CPPWINRT_OUTPUT_FILE}")
        add_library(${TARGET_NAME} INTERFACE IMPORTED)
        add_dependencies(${TARGET_NAME} ${PROJECTION_TARGET})
        set_target_properties(${TARGET_NAME} PROPERTIES
            CPPWINRT_EXECUTABLE_PATH "${CPPWINRT_EXECUTABLE_PATH}"
        )
        if(TARGET_NAME STREQUAL "Microsoft.Windows.CppWinRT")
            set_target_properties(${TARGET_NAME} PROPERTIES
                NUGET_LOCATION "${PACKAGE_LOCATION}"
                NUGET_VERSION "${PACKAGE_VERSION}"
                NUGET_DIRECTORY_SCOPED TRUE
            )
        endif()
    else()
        add_library(${TARGET_NAME} INTERFACE
            ${CPPWINRT_OUTPUT_FILE}
        )
    endif()

    target_include_directories(${TARGET_NAME} BEFORE
        INTERFACE
            ${CPPWINRT_OUTPUT}
    )

    target_link_libraries(${TARGET_NAME}
        INTERFACE
            RuntimeObject.lib
            ${CPPWINRT_DEPS}
    )

    list(APPEND CPPWINRT_REFS ${CPPWINRT_INPUTS})
    set_target_properties(${TARGET_NAME} PROPERTIES
        INTERFACE_CPPWINRT_REFS "${CPPWINRT_REFS}"
    )
endfunction()

block(SCOPE_FOR VARIABLES)
    # Create the Microsoft.Windows.CppWinRT target. This projection is based on the Windows SDK version being used.
    #
    # The Windows SDK version is determined in the following order:
    #   1. CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION (set by Visual Studio generator)
    #   2. WindowsSDKVersion environment variable (set by Visual Studio developer command prompt, used by a Ninja generator)
    #
    # If neither has been set, the 'sdk' keyword is used to target the latest installed SDK.
    if("${CPPWINRT_SYSTEM_VERSION}" STREQUAL "")
        if(NOT ("${CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION}" STREQUAL ""))
            set(CPPWINRT_SYSTEM_VERSION ${CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION})
        elseif(DEFINED ENV{WindowsSDKVersion})
            set(CPPWINRT_SYSTEM_VERSION "$ENV{WindowsSDKVersion}")

            # $ENV{WindowsSDKVersion} may have trailing characters - e.g. "10.0.19041.0\" - removing anything that's not a
            # '.'-delimited, four-part, integer version number
            string(REGEX REPLACE "^([0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+).*" "\\1" CPPWINRT_SYSTEM_VERSION "${CPPWINRT_SYSTEM_VERSION}")
        else()
            set(CPPWINRT_SYSTEM_VERSION sdk)
        endif()
    endif()

    add_cppwinrt_projection(Microsoft.Windows.CppWinRT
        INPUTS
            ${CPPWINRT_SYSTEM_VERSION}
        OPTIMIZE
    )

    target_link_libraries(Microsoft.Windows.CppWinRT
        INTERFACE
            ole32.lib
            oleaut32.lib
    )
endblock()
