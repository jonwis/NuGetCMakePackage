BeforeAll {
    $script:ScenarioDir    = $PSScriptRoot
    $script:RepoRoot       = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:NuGetToolsPath = if ($env:NUGET_TOOLS_PATH) { $env:NUGET_TOOLS_PATH } else { Join-Path $script:RepoRoot "__tools" }
    $script:BuildRoot      = Join-Path $script:RepoRoot "__build/scenario-basic"
    $script:NuGetConfigFile = if ($env:NUGET_SCENARIO_CONFIG_FILE) { $env:NUGET_SCENARIO_CONFIG_FILE } else { Join-Path $script:ScenarioDir "nuget.config" }
}

Describe "Basic Scenario" {
    It "Step 1: cmake configure generates packages.lock.json" {
        Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $script:ScenarioDir "packages.lock.json")

        cmake -S $script:ScenarioDir -B (Join-Path $script:BuildRoot "step1") --log-level=VERBOSE -DNUGET_TOOLS_PATH="$($script:NuGetToolsPath)" -DSCENARIO_NUGET_CONFIG_FILE="$($script:NuGetConfigFile)"

        $LASTEXITCODE | Should -Be 0
        Join-Path $script:ScenarioDir "packages.lock.json" |
            Should -Exist
    }

    It "Step 2: cmake configure verifies packages.lock.json" {
        cmake -S $script:ScenarioDir -B (Join-Path $script:BuildRoot "step2") --log-level=VERBOSE -DNUGET_TOOLS_PATH="$($script:NuGetToolsPath)" -DSCENARIO_NUGET_CONFIG_FILE="$($script:NuGetConfigFile)"

        $LASTEXITCODE |
            Should -Be 0
    }
}
