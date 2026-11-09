BeforeAll {
    $script:Build = Join-Path $PSScriptRoot "../../__build/scenario-cppwinrt-dependencies/$([Guid]::NewGuid())"
    $script:ProjectionStamp = $null
    function Invoke-ProjectionBuild {
        $output = & cmake --build $script:Build --target CppWinRTDependencies 2>&1
        $output | Write-Host
        $LASTEXITCODE | Should -Be 0
    }
}

Describe "C++/WinRT projection dependencies" -Skip:(!$IsWindows) {
    It "generates referenced metadata before the first projection" {
        & cmake -S "$PSScriptRoot/cppwinrt-dependencies" -B $script:Build -G Ninja "-DPOWERSHELL_EXECUTABLE=$((Get-Command pwsh).Source)"
        $LASTEXITCODE | Should -Be 0
        Join-Path $script:Build "reference.winmd" | Should -Not -Exist
        Invoke-ProjectionBuild
        Join-Path $script:Build "reference.winmd" | Should -Exist
        $projection = Get-Content (Join-Path $script:Build "reference-projection.txt") -Raw
        $script:ProjectionStamp = Join-Path $projection "output.log"
        $script:ProjectionStamp | Should -Exist
        Get-Content $script:ProjectionStamp -Raw | Should -Match "synthetic referenced metadata"
    }

    It "keeps an unchanged projection up to date" {
        $before = (Get-Item $script:ProjectionStamp).LastWriteTimeUtc
        $contents = Get-Content $script:ProjectionStamp -Raw
        Invoke-ProjectionBuild
        (Get-Item $script:ProjectionStamp).LastWriteTimeUtc | Should -Be $before
        Get-Content $script:ProjectionStamp -Raw | Should -Be $contents
    }

    It "regenerates when referenced metadata changes" {
        $before = (Get-Item $script:ProjectionStamp).LastWriteTimeUtc
        Start-Sleep -Milliseconds 1100
        (Get-Item (Join-Path $script:Build "reference.winmd")).LastWriteTimeUtc = [DateTime]::UtcNow
        Invoke-ProjectionBuild
        (Get-Item $script:ProjectionStamp).LastWriteTimeUtc | Should -BeGreaterThan $before
    }

    It "regenerates when the isolated generator changes" {
        $before = (Get-Item $script:ProjectionStamp).LastWriteTimeUtc
        Start-Sleep -Milliseconds 1100
        (Get-Item (Join-Path $script:Build "tool/bin/cppwinrt.exe")).LastWriteTimeUtc = [DateTime]::UtcNow
        Invoke-ProjectionBuild
        (Get-Item $script:ProjectionStamp).LastWriteTimeUtc | Should -BeGreaterThan $before
    }
}
