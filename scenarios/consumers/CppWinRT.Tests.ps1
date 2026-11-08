BeforeAll {
    $script:Build = Join-Path $PSScriptRoot "../../__build/scenario-cppwinrt-dependencies"
    $script:ProjectionStamp = $null
    function Invoke-SmokeBuild {
        $output = & cmake --build $script:Build --target CppWinRTSmoke 2>&1
        $output | Write-Host
        $LASTEXITCODE | Should -Be 0
    }
}

Describe "C++/WinRT projection dependencies" -Skip:(!$IsWindows) {
    It "generates referenced metadata before the first projection" {
        & cmake -S "$PSScriptRoot/cppwinrt-smoke" -B $script:Build -G Ninja
        $LASTEXITCODE | Should -Be 0
        Invoke-SmokeBuild
        Join-Path $script:Build "reference.winmd" | Should -Exist
        $projection = Get-Content (Join-Path $script:Build "reference-projection.txt") -Raw
        $script:ProjectionStamp = Join-Path $projection "output.log"
        $script:ProjectionStamp | Should -Exist
    }

    It "keeps an unchanged projection up to date" {
        $before = (Get-Item $script:ProjectionStamp).LastWriteTimeUtc
        Invoke-SmokeBuild
        (Get-Item $script:ProjectionStamp).LastWriteTimeUtc | Should -Be $before
    }

    It "regenerates when referenced metadata changes" {
        $before = (Get-Item $script:ProjectionStamp).LastWriteTimeUtc
        Start-Sleep -Milliseconds 1100
        (Get-Item (Join-Path $script:Build "reference.winmd")).LastWriteTimeUtc = [DateTime]::UtcNow
        Invoke-SmokeBuild
        (Get-Item $script:ProjectionStamp).LastWriteTimeUtc | Should -BeGreaterThan $before
    }

    It "regenerates when the isolated generator changes" {
        $before = (Get-Item $script:ProjectionStamp).LastWriteTimeUtc
        Start-Sleep -Milliseconds 1100
        (Get-Item (Join-Path $script:Build "tool/bin/cppwinrt.exe")).LastWriteTimeUtc = [DateTime]::UtcNow
        Invoke-SmokeBuild
        (Get-Item $script:ProjectionStamp).LastWriteTimeUtc | Should -BeGreaterThan $before
    }
}
