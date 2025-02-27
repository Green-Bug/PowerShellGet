# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

# Do NOT edit this file.  Edit dobuild.ps1
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
param (
    [Parameter(ParameterSetName="build")]
    [switch]
    $Clean,

    [Parameter(ParameterSetName="build")]
    [switch]
    $Build,

    [Parameter(ParameterSetName="publish")]
    [switch]
    $Publish,

    [Parameter(ParameterSetName="publish")]
    [switch]
    $Signed,

    [Parameter(ParameterSetName="build")]
    [switch]
    $Test,

    [Parameter(ParameterSetName="build")]
    [string[]]
    [ValidateSet("Functional","StaticAnalysis")]
    $TestType = @("Functional"),

    [Parameter(ParameterSetName="help")]
    [switch]
    $UpdateHelp,

    [ValidateSet("Debug", "Release")]
    [string] $BuildConfiguration = "Debug",

    [ValidateSet("netstandard2.0")]
    [string] $BuildFramework = "netstandard2.0"
)

if ( -not (Get-Module -ErrorAction SilentlyContinue PSPackageProject) -and -not (Import-Module -PassThru -ErrorAction SilentlyContinue PSPackageProject -MinimumVersion 0.1.18) ) {
    Install-Module -Name PSPackageProject -MinimumVersion 0.1.18 -Force
}

$config = Get-PSPackageProjectConfiguration -ConfigPath $PSScriptRoot

$script:ModuleName = $config.ModuleName
$script:FormatFileName = $config.FormatFileName
$script:SrcPath = $config.SourcePath
$script:OutDirectory = $config.BuildOutputPath
$script:SignedDirectory = $config.SignedOutputPath
$script:TestPath = $config.TestPath

$script:ModuleRoot = $PSScriptRoot
$script:Culture = $config.Culture
$script:HelpPath = $config.HelpPath

$script:BuildConfiguration = $BuildConfiguration
$script:BuildFramework = $BuildFramework

if ($env:TF_BUILD) {
    $vstsCommandString = "vso[task.setvariable variable=BUILD_OUTPUT_PATH]$OutDirectory"
    Write-Host ("sending " + $vstsCommandString)
    Write-Host "##$vstsCommandString"

    $vstsCommandString = "vso[task.setvariable variable=SIGNED_OUTPUT_PATH]$SignedDirectory"
    Write-Host ("sending " + $vstsCommandString)
    Write-Host "##$vstsCommandString"
}

. $PSScriptRoot/doBuild.ps1

if ($Clean) {
    if (Test-Path $OutDirectory) {
        Remove-Item -Path $OutDirectory -Force -Recurse -ErrorAction Stop -Verbose
    }

    if (Test-Path "${SrcPath}/code/bin")
    {
        Remove-Item -Path "${SrcPath}/code/bin" -Recurse -Force -ErrorAction Stop -Verbose
    }

    if (Test-Path "${SrcPath}/code/obj")
    {
        Remove-Item -Path "${SrcPath}/code/obj" -Recurse -Force -ErrorAction Stop -Verbose
    }
}

if (-not (Test-Path $OutDirectory))
{
    $script:OutModule = New-Item -ItemType Directory -Path (Join-Path $OutDirectory $ModuleName)
}
else
{
    $script:OutModule = Join-Path $OutDirectory $ModuleName
}

if ($Build.IsPresent)
{
    $sb = (Get-Item Function:DoBuild).ScriptBlock
    Invoke-PSPackageProjectBuild -BuildScript $sb -SkipPublish
}

if ($Publish.IsPresent)
{
    Invoke-PSPackageProjectPublish -Signed:$Signed.IsPresent -AllowPreReleaseDependencies
}

if ( $Test.IsPresent ) {
    Invoke-PSPackageProjectTest -Type $TestType
}

if ($UpdateHelp.IsPresent) {
    Add-PSPackageProjectCmdletHelp -ProjectRoot $ModuleRoot -ModuleName $ModuleName -Culture $Culture
}
