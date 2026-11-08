BeforeAll {
    $script:ScenarioDir = Join-Path $PSScriptRoot "framework"
    $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:TestRoot = Join-Path $script:RepoRoot "__build/scenario-framework"
    $script:Tools = if ($env:NUGET_TOOLS_PATH) { $env:NUGET_TOOLS_PATH } else { Join-Path $script:RepoRoot "__tools" }
    $script:Config = if ($env:NUGET_SCENARIO_CONFIG_FILE) { $env:NUGET_SCENARIO_CONFIG_FILE } else { Join-Path $PSScriptRoot "nuget.config" }
    $script:RunRoot = Join-Path $script:TestRoot ([guid]::NewGuid().ToString())
    New-Item $script:RunRoot -ItemType Directory -Force | Out-Null

    function Invoke-FrameworkConfigure($Name, $ExtraArgs = @(), $BinaryName = "build") {
        $root = Join-Path $script:RunRoot $Name
        New-Item $root -ItemType Directory -Force | Out-Null
        Push-Location $root
        try {
            $output = & cmake -S $script:ScenarioDir -B (Join-Path $root $BinaryName) --log-level=VERBOSE `
                "-DNUGET_TOOLS_PATH=$script:Tools" "-DSCENARIO_NUGET_CONFIG_FILE=$script:Config" `
                "-DSCENARIO_LOCK_FILE=$(Join-Path $root 'packages.lock.json')" @ExtraArgs 2>&1
            $exitCode = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        $output | Write-Host
        [pscustomobject]@{
            ExitCode = $exitCode
            Output = $output -join "`n"
            Root = $root
        }
    }
}

Describe "Target framework restoration" {
    It "restores <Name> and preserves its lock on reconfigure" -ForEach @(
        @{ Name = "scoped-default-mixed"; Framework = "native"; Api = "add_target_nuget_packages"; RestoreArgs = @() }
        @{ Name = "scoped-explicit-native"; Framework = "native"; Api = "add_target_nuget_packages"; RestoreArgs = @("-DSCENARIO_FRAMEWORK=native") }
        @{ Name = "scoped-explicit-managed"; Framework = "net8.0"; Api = "add_target_nuget_packages"; RestoreArgs = @("-DSCENARIO_FRAMEWORK=net8.0", "-DSCENARIO_MANAGED_ONLY=ON") }
        @{ Name = "legacy-default-managed"; Framework = "any"; Api = "add_nuget_packages"; RestoreArgs = @("-DSCENARIO_MANAGED_ONLY=ON") }
    ) {
        $arguments = @("-DSCENARIO_API=$Api") + $RestoreArgs
        $first = Invoke-FrameworkConfigure $Name $arguments
        $first.ExitCode | Should -Be 0
        $lockPath = Join-Path $first.Root "packages.lock.json"
        $hash = (Get-FileHash $lockPath).Hash
        $lock = Get-Content $lockPath -Raw | ConvertFrom-Json -AsHashtable
        $graph = @($lock.dependencies.Values)[0]
        $graph["Newtonsoft.Json"].resolved | Should -Be "13.0.3"
        if ("-DSCENARIO_MANAGED_ONLY=ON" -notin $RestoreArgs) {
            $graph["CLI11"].resolved | Should -Be "2.2.0"
        }
        $manifestPath = if ($Api -eq "add_target_nuget_packages") {
            Join-Path $first.Root "build/__nuget/1/packages.list.json"
        } else {
            Join-Path $first.Root "build/NuGetCMakePackage.Scenarios.Framework.packages.list.json"
        }
        (Get-Content $manifestPath -Raw | ConvertFrom-Json).targetFramework | Should -Be $Framework
        (Invoke-FrameworkConfigure $Name $arguments "locked-build").ExitCode | Should -Be 0
        (Get-FileHash $lockPath).Hash | Should -Be $hash
    }

    It "honors explicit any rather than accepting native-only CLI11" {
        $configure = Invoke-FrameworkConfigure "explicit-any-native" @("-DSCENARIO_FRAMEWORK=any")
        $configure.ExitCode | Should -Not -Be 0
        $configure.Output | Should -Match "CLI11 2\.2\.0 is not compatible with any"
    }

    It "retains the legacy any default for native-only packages" {
        $configure = Invoke-FrameworkConfigure "legacy-native" @("-DSCENARIO_API=add_nuget_packages")
        $configure.ExitCode | Should -Not -Be 0
        $configure.Output | Should -Match "CLI11 2\.2\.0 is not compatible with any"
    }

    It "requires an explicit any override to reuse an established any lock" {
        $arguments = @("-DSCENARIO_MANAGED_ONLY=ON", "-DSCENARIO_FRAMEWORK=any")
        $first = Invoke-FrameworkConfigure "any-lock" $arguments
        $first.ExitCode | Should -Be 0
        $lockPath = Join-Path $first.Root "packages.lock.json"
        $hash = (Get-FileHash $lockPath).Hash
        $changed = Invoke-FrameworkConfigure "any-lock" @("-DSCENARIO_MANAGED_ONLY=ON", "-DSCENARIO_FRAMEWORK=")
        $changed.ExitCode | Should -Not -Be 0
        $changed.Output | Should -Match "specified\s+NuGet\s+packages\s+differ\s+from\s+the\s+lock\s+file"
        (Get-FileHash $lockPath).Hash | Should -Be $hash
        (Invoke-FrameworkConfigure "any-lock" $arguments).ExitCode | Should -Be 0
        (Get-FileHash $lockPath).Hash | Should -Be $hash
    }
}
