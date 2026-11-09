$Executable = $args[0]
$CommandArguments = $args[1..($args.Count - 1)]
$ErrorActionPreference = "Stop"
try {
    if ([IO.Path]::GetFileName($Executable) -eq "cppwinrt.exe") {
        & ([scriptblock]::Create((Get-Content -LiteralPath $Executable -Raw))) @CommandArguments
    } else {
        & $Executable @CommandArguments
        exit $LASTEXITCODE
    }
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
