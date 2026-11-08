# End-to-end flow (implementation sequence)

## Index

- [Prerequisites](#prerequisites)
- [Flow](#flow)
- [Outputs](#outputs)

## Prerequisites

This sequence shows how the implementation in `CMakeLists.txt` resolves and exposes NuGet packages for `find_package`.

## Flow

```mermaid
sequenceDiagram
    autonumber
    participant Consumer as Consumer CMakeLists.txt
    participant FC as FetchContent
    participant NCP as NuGetCMakePackage (functions)
    participant FS as File System / CMake cache
    participant NN as NuNuGet CLI
    participant GP as NuGet Global Packages

    Consumer->>FC: Declare and make NuGetCMakePackage available
    FC->>NCP: Load module and expose add_nuget_packages

    Consumer->>NCP: Call add_nuget_packages with packages config and lock file
    NCP->>NCP: Validate required args and apply framework default any
    NCP->>NCP: Build package list JSON from name/version pairs
    NCP->>FS: Write package list JSON file in CMAKE_BINARY_DIR

    NCP->>NCP: ensure_nunuget()
    alt NUNUGET_PATH already known/found
        NCP->>FS: Cache NUNUGET_PATH
    else Download required
        NCP->>FS: Resolve NUGET_TOOLS_PATH (or default ${CMAKE_BINARY_DIR}/__tools)
        NCP->>FS: Select host-specific package + expected hash
        NCP->>FS: Download .nupkg and extract tools
        NCP->>FS: Cache extracted NUNUGET_PATH
    end

    NCP->>NN: Run nunuget install with config list and lock file
    NN->>GP: Resolve package graph + install into global packages path
    NN-->>NCP: Return global packages path and resolved package lines

    NCP->>NCP: Parse GlobalPackagesPath + resolved package entries
    loop For each resolved package
        NCP->>FS: Check duplicate/version conflicts via GLOBAL properties
        NCP->>FS: Probe for CMake entry points
        NCP->>FS: Set package root or dir variables based on CMake policies
        NCP->>FS: Set GLOBAL properties NUGET_VERSION-* and NUGET_LOCATION-*
    end

    NCP->>FS: Append LOCK_FILE to CMAKE_CONFIGURE_DEPENDS
    NCP-->>Consumer: Configuration complete and package discoverable
    Consumer->>NCP: find_package(Package CONFIG REQUIRED)
    Consumer->>Consumer: target_link_libraries(...)
```

## Outputs

- Resolved NuGet packages installed into the global packages path.
- Package discovery variables set for `find_package` (`*_ROOT` or `*_DIR`, policy-dependent).
- Global properties set for installed package version and location (`NUGET_VERSION-*`, `NUGET_LOCATION-*`).
- Lock file added to `CMAKE_CONFIGURE_DEPENDS` so configuration reruns when the lock file changes.
