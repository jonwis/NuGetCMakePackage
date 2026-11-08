BeforeAll {
    $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:ScenarioDir = $PSScriptRoot
    $script:TestRoot = Join-Path $script:RepoRoot "__build/scenario-consumers"
    $script:Feed = Join-Path $script:TestRoot "feed"
    $script:Locks = Join-Path $script:TestRoot "locks"
    $script:Build = Join-Path $script:TestRoot "build"
    $script:Tools = if ($env:NUGET_TOOLS_PATH) { $env:NUGET_TOOLS_PATH } else { Join-Path $script:RepoRoot "__tools" }
    $script:SavedEnvironment = @{}
    foreach ($name in @("NUGET_PACKAGES", "NUGET_SCRATCH")) {
        $script:SavedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
    }
    if (Test-Path $script:TestRoot) {
        Remove-Item $script:TestRoot -Recurse -Force
    }
    New-Item $script:Feed, $script:Locks -ItemType Directory -Force | Out-Null
    $env:NUGET_PACKAGES = Join-Path $script:TestRoot "packages"
    $env:NUGET_SCRATCH = Join-Path $script:TestRoot "scratch"

    function New-FixturePackage($Id, $Version, $Dependencies, $Files) {
        $dependencyXml = ""
        foreach ($dependency in $Dependencies) {
            $dependencyXml += "<dependency id=`"$dependency`" version=`"[$Version]`" />"
        }
        $nuspec = "<?xml version=`"1.0`"?><package><metadata><id>$Id</id><version>$Version</version><authors>Scenario</authors><description>Local consumer fixture</description><dependencies>$dependencyXml</dependencies></metadata></package>"
        $archive = [IO.Compression.ZipFile]::Open((Join-Path $script:Feed "$Id.$Version.nupkg"), [IO.Compression.ZipArchiveMode]::Create)
        try {
            $entries = @{}
            foreach ($key in $Files.Keys) { $entries[$key] = $Files[$key] }
            $entries["$Id.nuspec"] = $nuspec
            foreach ($key in $entries.Keys) {
                $entry = $archive.CreateEntry($key)
                $writer = [IO.StreamWriter]::new($entry.Open(), [Text.UTF8Encoding]::new($false))
                try { $writer.Write($entries[$key]) } finally { $writer.Dispose() }
            }
        } finally {
            $archive.Dispose()
        }
    }

    foreach ($version in @("1.0.0", "2.0.0", "3.0.0")) {
        $majorVersion = $version.Split(".")[0]
        foreach ($id in @("Fixture.Native", "Fixture.Dependency")) {
            $config = @'
include_guard()
get_filename_component(PACKAGE_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
add_library(@ID@ UNKNOWN IMPORTED)
set_target_properties(@ID@ PROPERTIES
    IMPORTED_LOCATION "${PACKAGE_ROOT}/runtimes/win-x64/native/fixture.lib"
    INTERFACE_INCLUDE_DIRECTORIES "${PACKAGE_ROOT}/include"
    FIXTURE_TOOL "${PACKAGE_ROOT}/tools/fixture.tool"
)
'@.Replace("@ID@", $id)
            $files = @{
                "build/cmake/$($id.ToLowerInvariant())-config.cmake" = $config
                "build/$id.props" = "<Project />"
                "include/fixture.h" = "#pragma once`ninline constexpr int $($id.ToLowerInvariant().Replace('.', '_'))_version = $majorVersion;`n"
                "runtimes/win-x64/native/fixture.lib" = "$id $version"
                "tools/fixture.tool" = "$id $version"
            }
            $dependencies = if ($id -eq "Fixture.Native") { @("Fixture.Dependency") } else { @() }
            New-FixturePackage $id $version $dependencies $files
        }
        New-FixturePackage "Microsoft.Windows.ImplementationLibrary" $version @() @{
            "include/wil/fixture.h" = "#pragma once`ninline constexpr int wil_fixture_version = $majorVersion;`n"
        }
        New-FixturePackage "Microsoft.Windows.CppWinRT" $version @() @{ "bin/cppwinrt.exe" = "Configure-only fixture"; "include/fixture.h" = "// CppWinRT $version" }
        New-FixturePackage "Microsoft.WindowsAppSDK.Runtime" $version @() @{ "include/fixture.h" = "// Runtime $version" }
        New-FixturePackage "Microsoft.WindowsAppSDK.InteractiveExperiences" $version @("Microsoft.Windows.CppWinRT") @{ "include/fixture.h" = "// InteractiveExperiences $version" }
        New-FixturePackage "Microsoft.WindowsAppSDK.Foundation" $version @("Microsoft.WindowsAppSDK.InteractiveExperiences", "Microsoft.WindowsAppSDK.Runtime") @{
            "include/fixture.h" = "// Foundation $version"
            "include/WindowsAppRuntimeAutoInitializer.cpp" = ""
            "include/MddBootstrapAutoInitializer.cpp" = ""
            "include/DeploymentManagerAutoInitializer.cpp" = ""
        }
        New-FixturePackage "Microsoft.WindowsAppSDK.ML" $version @("Microsoft.WindowsAppSDK.Foundation") @{
            "include/fixture.h" = "// ML $version"
            "include/WindowsMLAutoInitializer.cpp" = ""
            "include/WindowsMLAutoInitializer.SelfContained.cpp" = ""
        }
    }
    $script:Config = Join-Path $script:TestRoot "nuget.config"
    $escapedFeed = [Security.SecurityElement]::Escape($script:Feed)
    [IO.File]::WriteAllText($script:Config, "<?xml version=`"1.0`"?><configuration><packageSources><clear/><add key=`"fixtures`" value=`"$escapedFeed`"/></packageSources><packageSourceMapping><clear/><packageSource key=`"fixtures`"><package pattern=`"*`"/></packageSource></packageSourceMapping></configuration>")

    function Invoke-ConsumerConfigure($BinaryDir, $LockDir, $ExtraArgs = @(), $SourceDir = $script:ScenarioDir) {
        New-Item $BinaryDir -ItemType Directory -Force | Out-Null
        Push-Location $BinaryDir
        try {
            $output = & cmake -S $SourceDir -B $BinaryDir --log-level=VERBOSE "-DCMAKE_BUILD_TYPE=Debug" "-DNUGET_TOOLS_PATH=$script:Tools" "-DFIXTURE_CONFIG=$script:Config" "-DLOCK_ROOT=$LockDir" @ExtraArgs 2>&1
            $exitCode = $LASTEXITCODE
            $output | Write-Host
            [pscustomobject]@{
                ExitCode = $exitCode
                Output = $output -join "`n"
            }
        } finally {
            Pop-Location
        }
    }

}

AfterAll {
    foreach ($name in $script:SavedEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $script:SavedEnvironment[$name])
    }
}

Describe "Legacy global consumers" {
    It "preserves global metadata, repeated discovery, overlay targets and projection paths" {
        $root = Join-Path $script:TestRoot "legacy"
        $locks = Join-Path $root "locks"
        New-Item $locks -ItemType Directory -Force | Out-Null
        $configure = Invoke-ConsumerConfigure (Join-Path $root "build") $locks @() (Join-Path $script:ScenarioDir "legacy")
        $configure.ExitCode | Should -Be 0
        Join-Path $root "build/LegacyPackages.packages.list.json" | Should -Exist
        Join-Path $root "build/a/__nuget" | Should -Not -Exist
        Join-Path $root "build/b/__nuget" | Should -Not -Exist
    }

    It "retains the legacy global version conflict error" {
        $root = Join-Path $script:TestRoot "legacy-conflict"
        $locks = Join-Path $root "locks"
        New-Item $locks -ItemType Directory -Force | Out-Null
        $configure = Invoke-ConsumerConfigure (Join-Path $root "build") $locks @("-DLEGACY_CONFLICT=ON") (Join-Path $script:ScenarioDir "legacy")
        $configure.ExitCode | Should -Not -Be 0
        $configure.Output | Should -Match "(?s)add_nuget_packages:.*already\s+been\s+added\s+with\s+version"
    }

    It "rejects overlapping APIs in <Order> order" -ForEach @(
        @{ Order = "global-first" }
        @{ Order = "target-first" }
    ) {
        $root = Join-Path $script:TestRoot "mixed-$Order"
        $locks = Join-Path $root "locks"
        New-Item $locks -ItemType Directory -Force | Out-Null
        $configure = Invoke-ConsumerConfigure (Join-Path $root "build") $locks @("-DMIXED_MODE=$Order") (Join-Path $script:ScenarioDir "legacy")
        $configure.ExitCode | Should -Not -Be 0
        $configure.Output | Should -Match "Do\s+not\s+mix\s+global\s+and\s+target-scoped\s+APIs"
    }
}

Describe "Independent consumers" {
    It "resolves sibling version graphs and reuses same-version cache entries" {
        $configure = Invoke-ConsumerConfigure $script:Build $script:Locks @("-DFixture.Native_DIR=/incorrect/cached/config")
        $configure.ExitCode | Should -Be 0
        foreach ($consumer in @("a", "b", "c")) {
            $version = if ($consumer -eq "b") { "2.0.0" } else { "1.0.0" }
            $lock = Get-Content (Join-Path $script:Locks "$consumer.packages.lock.json") -Raw | ConvertFrom-Json -AsHashtable
            $graph = @($lock.dependencies.Values)[0]
            $graph["Fixture.Native"].resolved | Should -Be $version
            $graph["Fixture.Dependency"].resolved | Should -Be $version
            $graph["Fixture.Dependency"].type | Should -Be "Transitive"
            foreach ($index in @(1, 2)) {
                $manifestPath = Join-Path $script:Build "$consumer/__nuget/$index/packages.list.json"
                $manifestPath | Should -Exist
                $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
                ($manifest.packages | Where-Object id -EQ "Fixture.Native").version | Should -Be $version
            }
        }
        $firstLock = Get-Content (Join-Path $script:Locks "a.packages.lock.json") -Raw
        $firstLock | Should -Be (Get-Content (Join-Path $script:Locks "c.packages.lock.json") -Raw)
        Join-Path $script:Build "obj" | Should -Not -Exist
        @(Get-ChildItem (Join-Path $env:NUGET_PACKAGES "fixture.native") -Directory).Count | Should -Be 2
        $script:CacheMarker = Join-Path $env:NUGET_PACKAGES "fixture.native/1.0.0/cache-reuse-marker"
        Set-Content $script:CacheMarker "Retain extracted cache"
        cmake --build $script:Build --config Debug --target Clienta Clientb Clientc
        $LASTEXITCODE | Should -Be 0
        $script:ClientArtifacts = @{}
        foreach ($consumer in @("a", "b", "c")) {
            $artifact = Get-Content (Join-Path $script:Build "$consumer/client-artifact-Debug.txt") -Raw
            $script:ClientArtifacts[$artifact] = (Get-Item $artifact).LastWriteTimeUtc
        }
    }

    It "reconfigures with locked graphs and retains extracted packages" {
        $configure = Invoke-ConsumerConfigure $script:Build $script:Locks
        $configure.ExitCode | Should -Be 0
        $script:CacheMarker | Should -Exist
        cmake --build $script:Build --config Debug --target Clienta Clientb Clientc
        $LASTEXITCODE | Should -Be 0
        foreach ($artifact in $script:ClientArtifacts.Keys) {
            (Get-Item $artifact).LastWriteTimeUtc | Should -Be $script:ClientArtifacts[$artifact]
        }
    }

    It "replaces stale discovery when versions change in the same build tree" {
        $locks = Join-Path $script:TestRoot "changed-locks"
        New-Item $locks -ItemType Directory -Force | Out-Null
        $configure = Invoke-ConsumerConfigure $script:Build $locks @("-DVERSION_A=2.0.0", "-DVERSION_B=1.0.0")
        $configure.ExitCode | Should -Be 0
        cmake --build $script:Build --config Debug --target Clienta Clientb Clientc
        $LASTEXITCODE | Should -Be 0
    }

    It "preserves NuNuGet locked-mode mismatch errors" {
        $configure = Invoke-ConsumerConfigure (Join-Path $script:TestRoot "locked-mismatch") $script:Locks @("-DVERSION_A=2.0.0")
        $configure.ExitCode | Should -Not -Be 0
        $configure.Output | Should -Match "specified\s+NuGet\s+packages\s+differ\s+from\s+the\s+lock\s+file"
    }

    It "rejects incompatible repeated versions in one consumer" {
        $locks = Join-Path $script:TestRoot "conflict-locks"
        New-Item $locks -ItemType Directory -Force | Out-Null
        $configure = Invoke-ConsumerConfigure (Join-Path $script:TestRoot "conflict") $locks @("-DSAME_CONSUMER_CONFLICT=ON")
        $configure.ExitCode | Should -Not -Be 0
        $configure.Output | Should -Match "already\s+been\s+added\s+in\s+this\s+consumer"
    }

    It "rejects incompatible versions inherited from an ancestor consumer" {
        $locks = Join-Path $script:TestRoot "nested-locks"
        New-Item $locks -ItemType Directory -Force | Out-Null
        $configure = Invoke-ConsumerConfigure (Join-Path $script:TestRoot "nested") $locks @("-DNESTED_CONFLICT=ON")
        $configure.ExitCode | Should -Not -Be 0
        $configure.Output | Should -Match "conflicts\s+with\s+ancestor\s+consumer"
    }

    It "restores concurrent configure trees through the shared standard cache and scratch" {
        $cacheEntry = Select-String -LiteralPath (Join-Path $script:Build "CMakeCache.txt") -Pattern '^NUNUGET_PATH:FILEPATH=(.+)$'
        $nunuget = $cacheEntry.Matches[0].Groups[1].Value
        $nunuget | Should -Exist
        $processes = @()
        try {
            foreach ($consumer in @("parallel-a", "parallel-b")) {
                $root = Join-Path $script:TestRoot $consumer
                $locks = Join-Path $root "locks"
                New-Item $locks -ItemType Directory -Force | Out-Null
                $start = [Diagnostics.ProcessStartInfo]::new((Get-Command cmake).Source)
                $start.UseShellExecute = $false
                $start.RedirectStandardOutput = $true
                $start.RedirectStandardError = $true
                foreach ($argument in @("-S", $script:ScenarioDir, "-B", (Join-Path $root "build"),
                    "-DNUGET_TOOLS_PATH=$script:Tools", "-DNUNUGET_PATH:FILEPATH=$nunuget", "-DFIXTURE_CONFIG=$script:Config", "-DLOCK_ROOT=$locks",
                    "-DVERSION_A=3.0.0", "-DVERSION_B=3.0.0")) {
                    $start.ArgumentList.Add($argument)
                }
                $process = [Diagnostics.Process]::Start($start)
                $processes += @{
                    Process = $process
                    Output = $process.StandardOutput.ReadToEndAsync()
                    Error = $process.StandardError.ReadToEndAsync()
                }
            }
            foreach ($item in $processes) {
                $item.Process.WaitForExit()
                $item.Output.GetAwaiter().GetResult() | Write-Host
                $item.Error.GetAwaiter().GetResult() | Write-Host
                $item.Process.ExitCode | Should -Be 0
            }
            Join-Path $env:NUGET_PACKAGES "fixture.native/3.0.0/.nupkg.metadata" | Should -Exist
        } finally {
            foreach ($item in $processes) {
                $item.Process.WaitForExit()
                $item.Process.Dispose()
            }
        }
    }
}
