param(
    [string] $Output,
    [Alias("input")] [string[]] $InputMetadata,
    [Alias("ref")] [string[]] $ReferenceMetadata,
    [switch] $Optimize
)

foreach ($metadata in @($InputMetadata) + @($ReferenceMetadata)) {
    Get-Content -LiteralPath $metadata -Raw
}
"Mock projection generation $([Guid]::NewGuid())"
