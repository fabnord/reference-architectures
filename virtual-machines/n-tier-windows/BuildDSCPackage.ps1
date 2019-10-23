Param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path -Path $(Resolve-Path $_) -PathType Leaf})]
    [string]$DscScript
)

$ErrorActionPreference = "Stop"
$DscScriptFileInfo = [System.IO.FileInfo][string]$(Resolve-Path $DscScript)
$OutputArchivePath = "$($DscScriptFileInfo.FullName).zip"

. $DscScriptFileInfo.FullName

Get-ChildItem Function: | `
    Where-Object {$_.ScriptBlock.File -eq $DscScriptFileInfo -and $_.CommandType -eq "Configuration"} | `
    ForEach-Object {
        $parameters = & $(Join-Path -Path $DscScriptFileInfo.DirectoryName -ChildPath "$($_.Name)Parameters.ps1")
        Write-Host "Running configuration function '$($_.Name)'"
        & $_.Name @parameters
        Write-Host
    }

Write-Host "Publishing VM DSC Configuration"
Publish-AzureRmVMDscConfiguration $DscScriptFileInfo.FullName -OutputArchivePath $OutputArchivePath -Force
