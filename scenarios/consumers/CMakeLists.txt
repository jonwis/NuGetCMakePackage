cmake_minimum_required(VERSION 3.31)
project(NuGetCMakePackage.Scenarios.Consumers LANGUAGES CXX)

include(FetchContent)
FetchContent_Declare(NuGetCMakePackage SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/../..")
FetchContent_MakeAvailable(NuGetCMakePackage)

set(VERSION_A "1.0.0" CACHE STRING "First consumer's version")
set(VERSION_B "2.0.0" CACHE STRING "Second consumer's version")
set(Microsoft.Windows.ImplementationLibrary_ROOT "/incorrect/inherited/root")
set(MICROSOFT.WINDOWS.IMPLEMENTATIONLIBRARY_ROOT "/incorrect/inherited/root")
set(Fixture.Native_ROOT "/incorrect/inherited/root")
set(FIXTURE.NATIVE_ROOT "/incorrect/inherited/root")

add_subdirectory(a)
add_subdirectory(b)
add_subdirectory(c)

if(TARGET Microsoft.Windows.ImplementationLibrary OR TARGET Fixture.Native)
    message(FATAL_ERROR "Consumer targets leaked to the parent directory.")
endif()
