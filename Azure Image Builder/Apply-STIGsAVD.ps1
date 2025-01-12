<#
.SYNOPSIS
    This script uses the local group policy object tool (lgpo.exe) to apply the applicable DISA STIGs GPOs either downloaded directly from CyberCom or
    the files are contained with this script in the root of a folder.
.NOTES
    To use this script offline, download the lgpo tool from 'https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/LGPO.zip' and store it in the root of the folder where the script is located.'
    to the root of the folder where this script is located. Then download the latest STIG GPOs ZIP from 'https://public.cyber.mil/stigs/gpo' and and save at at STIGs.zip in the root
    of the folder where this script is located.

    This script not only applies the GPO objects but it also applies some registry settings and other mitigations. Ensure that these other items still apply through the
    lifecycle of the script.
#>
[CmdletBinding()]
param (
    [Parameter()]
    [bool]$AIB = $True
)
#region Initialization
$Script:FullName = $MyInvocation.MyCommand.Path
$Script:File = $MyInvocation.MyCommand.Name
$Script:Name=[System.IO.Path]::GetFileNameWithoutExtension($Script:File)
$virtualMachine = Get-WmiObject -Class Win32_ComputerSystem | Where-Object {$_.Model -match 'Virtual'}
$osCaption = (Get-WmiObject -Class Win32_OperatingSystem).caption
If ($osCaption -match 'Windows 11') { $osVersion = 11 } Else { $osVersion = 10 }
[String]$Script:LogDir = "$($env:SystemRoot)\Logs\Configuration"
If (-not(Test-Path -Path $Script:LogDir)) {
    New-Item -Path $Script:LogDir -ItemType Dir -Force | Out-Null
}
$Script:TempDir = Join-Path -Path $env:Temp -ChildPath $Script:Name
If (Test-Path -Path $Script:TempDir) {Remove-Item -Path $Script:TempDir -Recurse -ErrorAction SilentlyContinue}
New-Item -Path $Script:TempDir -ItemType Directory -Force | Out-Null
#endregion

#region Functions

Function Get-InternetFile {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [uri]$Url,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$OutputDirectory,
        [Parameter(Mandatory = $false, Position = 2)]
        [string]$OutputFileName
    )

    Begin {
        $ProgressPreference = 'SilentlyContinue'
        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Log -Message "Starting ${CmdletName} with the following parameters: $PSBoundParameters"
    }
    Process {

        $start_time = Get-Date

        If (!$OutputFileName) {
            Write-Log -Message "${CmdletName}: No OutputFileName specified. Trying to get file name from URL."
            If ((split-path -path $Url -leaf).Contains('.')) {

                $OutputFileName = split-path -path $url -leaf
                Write-Log -Message "${CmdletName}: Url contains file name - '$OutputFileName'."
            }
            Else {
                Write-Log -Message "${CmdletName}: Url does not contain file name. Trying 'Location' Response Header."
                $request = [System.Net.WebRequest]::Create($url)
                $request.AllowAutoRedirect=$false
                $response=$request.GetResponse()
                $Location = $response.GetResponseHeader("Location")
                If ($Location) {
                    $OutputFileName = [System.IO.Path]::GetFileName($Location)
                    Write-Log -Message "${CmdletName}: File Name from 'Location' Response Header is '$OutputFileName'."
                }
                Else {
                    Write-Log -Message "${CmdletName}: No 'Location' Response Header returned. Trying 'Content-Disposition' Response Header."
                    $result = Invoke-WebRequest -Method GET -Uri $Url -UseBasicParsing
                    $contentDisposition = $result.Headers.'Content-Disposition'
                    If ($contentDisposition) {
                        $OutputFileName = $contentDisposition.Split("=")[1].Replace("`"","")
                        Write-Log -Message "${CmdletName}: File Name from 'Content-Disposition' Response Header is '$OutputFileName'."
                    }
                }
            }
        }

        If ($OutputFileName) { 
            $wc = New-Object System.Net.WebClient
            $OutputFile = Join-Path $OutputDirectory $OutputFileName
            Write-Log -Message "${CmdletName}: Downloading file at '$url' to '$OutputFile'."
            Try {
                $wc.DownloadFile($url, $OutputFile)
                $time = (Get-Date).Subtract($start_time).Seconds
                
                Write-Log -Message "${CmdletName}: Time taken: '$time' seconds."
                if (Test-Path -Path $outputfile) {
                    $totalSize = (Get-Item $outputfile).Length / 1MB
                    Write-Log -Message "${CmdletName}: Download was successful. Final file size: '$totalsize' mb"
                    Return $OutputFile
                }
            }
            Catch {
                Write-Error "${CmdletName}: Error downloading file. Please check url."
                Return $Null
            }
        }
        Else {
            Write-Error "${CmdletName}: No OutputFileName specified. Unable to download file."
            Return $Null
        }
    }
    End {
        Write-Log -Message "Ending ${CmdletName}"
    }
}

Function Get-InternetUrl {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [uri]$Url,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$searchstring
    )
    Begin {
        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Log -Message "${CmdletName}: Starting ${CmdletName} with the following parameters: $PSBoundParameters"
    }
    Process {

        Try {
            Write-Log -Message -message "${CmdletName}: Now extracting download URL from '$Url'."
            $HTML = Invoke-WebRequest -Uri $Url -UseBasicParsing
            $Links = $HTML.Links
            $ahref = $null
            $ahref=@()
            $ahref = ($Links | Where-Object {$_.href -like "*$searchstring*"}).href
            If ($ahref.count -eq 0 -or $null -eq $ahref) {
                $ahref = ($Links | Where-Object {$_.OuterHTML -like "*$searchstring*"}).href
            }
            If ($ahref.Count -eq 1) {
                Write-Log -Message -Message "${CmdletName}: Download URL = '$ahref'"
                $ahref

            }
            Elseif ($ahref.Count -gt 1) {
                Write-Log -Message -Message "${CmdletName}: Download URL = '$($ahref[0])'"
                $ahref[0]
            }
        }
        Catch {
            Write-Error "${CmdletName}: Error Downloading HTML and determining link for download."
        }
    }
    End {
        Write-Log -Message -Message "${CmdletName}: Ending ${CmdletName}"
    }
}

Function Invoke-LGPO {
    [CmdletBinding()]
    Param (
        [string]$InputDir = $Script:TempDir,
        [string]$SearchTerm
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {
        Write-Log -Message "${CmdletName}: Gathering Registry text files for LGPO from '$InputDir'"
        Write-Log -Message "${CmdletName}: Gathering Security Templates files for LGPO from '$InputDir'"
        [array]$RegistryFiles = @()
        [array]$SecurityTemplates = @()
        If ($SearchTerm) {
            $RegistryFiles = Get-ChildItem -Path $InputDir -Filter "$SearchTerm*.txt"
            $SecurityTemplates = Get-ChildItem -Path $InputDir -Filter "$SearchTerm*.inf"
        }
        Else {
            $RegistryFiles = Get-ChildItem -Path $InputDir -Filter "*.txt"
            $SecurityTemplates = Get-ChildItem -Path $InputDir -Filter '*.inf'
        }
        ForEach ($RegistryFile in $RegistryFiles) {
            $TxtFilePath = $RegistryFile.FullName
            Write-Log -Message "${CmdletName}: Now applying settings from '$txtFilePath' to Local Group Policy via LGPO.exe."
            $lgporesult = Start-Process -FilePath 'lgpo.exe' -ArgumentList "/t `"$TxtFilePath`"" -Wait -PassThru
            Write-Log -Message "${CmdletName}: LGPO exitcode: '$($lgporesult.exitcode)'"
        }
        ForEach ($SecurityTemplate in $SecurityTemplates) {        
            $SecurityTemplate = $SecurityTemplate.FullName
            Write-Log -Message "${CmdletName}: Now applying security settings from '$SecurityTemplate' to Local Security Policy via LGPO.exe."
            $lgporesult = Start-Process -FilePath 'lgpo.exe' -ArgumentList "/s `"$SecurityTemplate`"" -Wait -PassThru
            Write-Log -Message "${CmdletName}: LGPO exitcode: '$($lgporesult.exitcode)'"
        }
    }
    End {
    }
}

function New-Log {
    <#
    .SYNOPSIS
    Sets default log file and stores in a script accessible variable $script:Log
    Log File name "packageExecution_$date.log"

    .PARAMETER Path
    Path to the log file

    .EXAMPLE
    New-Log c:\Windows\Logs
    Create a new log file in c:\Windows\Logs
    #>

    Param (
        [Parameter(Mandatory = $true, Position=0)]
        [string] $Path
    )

    # Create central log file with given date

    $date = Get-Date -UFormat "%Y-%m-%d %H-%M-%S"
    Set-Variable logFile -Scope Script
    $script:logFile = "$Script:Name-$date.log"

    if ((Test-Path $path ) -eq $false) {
        $null = New-Item -Path $path -type directory
    }

    $script:Log = Join-Path $path $logfile

    Add-Content $script:Log "Date`t`t`tCategory`t`tDetails"
}

function Write-Log {

    <#
    .SYNOPSIS
    Creates a log file and stores logs based on categories with tab seperation

    .PARAMETER category
    Category to put into the trace

    .PARAMETER message
    Message to be loged

    .EXAMPLE
    Log 'Info' 'Message'

    #>

    Param (
        [Parameter(Mandatory=$false, Position=0)]
        [ValidateSet("Info","Warning","Error")]
        $category = 'Info',
        [Parameter(Mandatory=$true, Position=1)]
        $message
    )

    $date = get-date
    $content = "[$date]`t$category`t`t$message`n" 
    Add-Content $Script:Log $content -ErrorAction Stop
    Write-Output $Content
}

Function Set-BluetoothRadioStatus {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Off', 'On')]
        [string]$BluetoothStatus
    )
    If ((Get-Service bthserv).Status -eq 'Stopped') { Start-Service bthserv }
    Try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime
        $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
        Function Await($WinRtTask, $ResultType) {
            $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
            $netTask = $asTask.Invoke($null, @($WinRtTask))
            $netTask.Wait(-1) | Out-Null
            $netTask.Result
        }
        [Windows.Devices.Radios.Radio,Windows.System.Devices,ContentType=WindowsRuntime] | Out-Null
        [Windows.Devices.Radios.RadioAccessStatus,Windows.System.Devices,ContentType=WindowsRuntime] | Out-Null
        Await ([Windows.Devices.Radios.Radio]::RequestAccessAsync()) ([Windows.Devices.Radios.RadioAccessStatus]) | Out-Null
        $radios = Await ([Windows.Devices.Radios.Radio]::GetRadiosAsync()) ([System.Collections.Generic.IReadOnlyList[Windows.Devices.Radios.Radio]])
        If ($radios) {
            $bluetooth = $radios | Where-Object { $_.Kind -eq 'Bluetooth' }
        }
        If ($bluetooth) {
            [Windows.Devices.Radios.RadioState,Windows.System.Devices,ContentType=WindowsRuntime] | Out-Null
            Await ($bluetooth.SetStateAsync($BluetoothStatus)) ([Windows.Devices.Radios.RadioAccessStatus]) | Out-Null
        }
    } Catch {
        Write-Warning "Set-BluetoothStatus function errored."
    }
}

Function Update-LocalGPOTextFile {
    [CmdletBinding(DefaultParameterSetName = 'Set')]
    Param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Set')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Delete')]
        [Parameter(Mandatory = $true, ParameterSetName = 'DeleteAllValues')]
        [ValidateSet('Computer', 'User')]
        [string]$scope,
        [Parameter(Mandatory = $true, ParameterSetName = 'Set')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Delete')]
        [Parameter(Mandatory = $true, ParameterSetName = 'DeleteAllValues')]
        [string]$RegistryKeyPath,
        [Parameter(Mandatory = $true, ParameterSetName = 'Set')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Delete')]
        [Parameter(Mandatory = $true, ParameterSetName = 'DeleteAllValues')]
        [string]$RegistryValue,
        [Parameter(Mandatory = $true, ParameterSetName = 'Set')]
        [AllowEmptyString()]
        [string]$RegistryData,
        [Parameter(Mandatory = $true, ParameterSetName = 'Set')]
        [ValidateSet('DWORD', 'String')]
        [string]$RegistryType,
        [Parameter(Mandatory = $false, ParameterSetName = 'Delete')]
        [switch]$Delete,
        [Parameter(Mandatory = $false, ParameterSetName = 'DeleteAllValues')]
        [switch]$DeleteAllValues,
        [string]$outputDir = $Script:TempDir,
        [string]$outfileprefix = $appName
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {
        # Convert $RegistryType to UpperCase to prevent LGPO errors.
        $ValueType = $RegistryType.ToUpper()
        # Change String type to SZ for text file
        If ($ValueType -eq 'STRING') { $ValueType = 'SZ' }
        # Replace any incorrect registry entries for the format needed by text file.
        $modified = $false
        $SearchStrings = 'HKLM:\', 'HKCU:\', 'HKEY_CURRENT_USER:\', 'HKEY_LOCAL_MACHINE:\'
        ForEach ($String in $SearchStrings) {
            If ($RegistryKeyPath.StartsWith("$String") -and $modified -ne $true) {
                $index = $String.Length
                $RegistryKeyPath = $RegistryKeyPath.Substring($index, $RegistryKeyPath.Length - $index)
                $modified = $true
            }
        }
        
        #Create the output file if needed.
        $Outfile = "$OutputDir\$Outfileprefix-$Scope.txt"
        If (-not (Test-Path -LiteralPath $Outfile)) {
            If (-not (Test-Path -LiteralPath $OutputDir -PathType 'Container')) {
                Try {
                    $null = New-Item -Path $OutputDir -Type 'Directory' -Force -ErrorAction 'Stop'
                }
                Catch {}
            }
            $null = New-Item -Path $outputdir -Name "$OutFilePrefix-$Scope.txt" -ItemType File -ErrorAction Stop
        }

        Write-Log -Message "${CmdletName}: Adding registry information to '$outfile' for LGPO.exe"
        # Update file with information
        Add-Content -Path $Outfile -Value $Scope
        Add-Content -Path $Outfile -Value $RegistryKeyPath
        Add-Content -Path $Outfile -Value $RegistryValue
        If ($Delete) {
            Add-Content -Path $Outfile -Value 'DELETE'
        }
        ElseIf ($DeleteAllValues) {
            Add-Content -Path $Outfile -Value 'DELETEALLVALUES'
        }
        Else {
            Add-Content -Path $Outfile -Value "$($ValueType):$RegistryData"
        }
        Add-Content -Path $Outfile -Value ""
    }
    End {        
    }
}

#endregion

#region Main

New-Log -Path $Script:LogDir
Write-Log -message "Starting '$PSCommandPath'."

If (-not(Test-Path -Path "$env:SystemRoot\System32\Lgpo.exe")) {
    $LGPOZip = Join-Path -Path $PSScriptRoot -ChildPath 'LGPO.zip'
    If (Test-Path -Path $LGPOZip) {
        Write-Log -message "Expanding '$LGPOZip' to '$Script:TempDir'."
        Expand-Archive -path $LGPOZip -DestinationPath $Script:TempDir -force
        $algpoexe = Get-ChildItem -Path $Script:TempDir -filter 'lgpo.exe' -recurse
        If ($algpoexe.count -gt 0) {
            $fileLGPO = $algpoexe[0].FullName
            Write-Log -message "Copying '$fileLGPO' to '$env:SystemRoot\system32'."
            Copy-Item -Path $fileLGPO -Destination "$env:SystemRoot\System32" -force        
        }
    } Else {
        $urlLGPO = 'https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/LGPO.zip'
        $LGPOZip = Get-InternetFile -Url $urlLGPO -OutputDirectory $Script:TempDir -Verbose
        $outputDir = Join-Path $Script:TempDir -ChildPath 'LGPO'
        Expand-Archive -Path $LGPOZip -DestinationPath $outputDir
        Remove-Item $LGPOZip -Force
        $fileLGPO = (Get-ChildItem -Path $outputDir -file -Filter 'lgpo.exe' -Recurse)[0].FullName
        Write-Log -Message "Copying `"$fileLGPO`" to System32"
        Copy-Item -Path $fileLGPO -Destination "$env:SystemRoot\System32" -Force
        Remove-Item -Path $outputDir -Recurse -Force
    }
}

$stigZip = Join-Path -Path $PSScriptRoot -ChildPath 'STIGs.zip'
If (-not (Test-Path -Path $stigZip)) {
    #Download the STIG GPOs
    $uriSTIGs = 'https://public.cyber.mil/stigs/gpo'
    $uriGPODownload = Get-InternetUrl -Url $uriSTIGs -searchstring 'GPOs'
    Write-Log -Message "Downloading STIG GPOs from `"$uriGPODownload`"."
    If ($uriGPODownload) {
        $stigZip = Get-InternetFile -url $uriGPODownload -OutputDirectory $Script:TempDir -Verbose
    }
} 

Expand-Archive -Path $stigZip -DestinationPath $Script:TempDir -Force
Write-Log -message "Copying ADMX and ADML files to local system."

$null = Get-ChildItem -Path $Script:TempDir -File -Recurse -Filter '*.admx' | ForEach-Object { Copy-Item -Path $_.FullName -Destination "$env:WINDIR\PolicyDefinitions\" -Force }
$null = Get-ChildItem -Path $Script:TempDir -Directory -Recurse | Where-Object {$_.Name -eq 'en-us'} | Get-ChildItem -File -recurse -filter '*.adml' | ForEach-Object { Copy-Item -Path $_.FullName -Destination "$env:WINDIR\PolicyDefinitions\en-us\" -Force }

Write-Log -message "Getting List of Applicable GPO folders."
$arrApplicableGPOs = Get-ChildItem -Path $Script:TempDir | Where-Object {$_.Name -like "DoD*Windows $osVersion*" -or $_.Name -like 'DoD*Edge*' -or $_.Name -like 'DoD*Firewall*' -or $_.Name -like 'DoD*Internet Explorer*' -or $_.Name -like 'DoD*Defender Antivirus*'} 
[array]$arrGPOFolders = $null
ForEach ($folder in $arrApplicableGPOs.FullName) {
    $gpoFolderPath = (Get-ChildItem -Path $folder -Filter 'GPOs' -Directory).FullName
    $arrGPOFolders += $gpoFolderPath
}
ForEach ($gpoFolder in $arrGPOFolders) {
    Write-Log -message "Running 'LGPO.exe /g `"$gpoFolder`"'"
    $lgpo = Start-Process -FilePath "$env:SystemRoot\System32\lgpo.exe" -ArgumentList "/g `"$gpoFolder`"" -Wait -PassThru
    Write-Log -message "'lgpo.exe' exited with code [$($lgpo.ExitCode)]."
}
$SecFileContent = @'
[Unicode]
Unicode=yes
[Version]
signature="$CHICAGO$"
Revision=1
[Privilege Rights]
SeDenyNetworkLogonRight = *S-1-5-32-546
'@
If ($AIB -eq $True) {
    # Applying Azure Image Builder Exceptions
    Write-Log -message "Applying Azure Image Builder Exceptions."
    $appName = 'AzureImageBuilder-Exceptions'
    $SecFile = Join-Path -Path $Script:TempDir -ChildPath "$appName.inf"
    $SecFileContent | Out-File -FilePath $SecFile -Encoding unicode
    #V-253418 Tje Windows Remote Management (WinRM) service must not use Basic authentication.
    Update-LocalGPOTextFile -outfileprefix $appName -scope 'Computer' -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\Windows\WinRM\Service' -RegistryValue 'AllowBasic' -Delete
    #V-253419 The Windows Remote Management (WinRM) service must not allow unencrypted traffic.
    Update-LocalGPOTextFile -outfileprefix $appName -scope 'Computer' -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\Windows\WinRM\Service' -RegistryValue 'AllowUnencryptedTraffic' -Delete
    Invoke-LGPO -SearchTerm $appName
    $winrm = Start-Process -FilePath winrm -ArgumentList 'set winrm/config/service @{AllowUnencrypted="true"}' -Passthru -Wait
    Write-Log -message "winrm command to allow unencrypted comms exited with exit code $($winrm.exitcode)"
    $winrm = Start-Process -FilePath winrm -ArgumentList 'set winrm/config/service/auth @{Basic="true"}' -Passthru -Wait
    Write-Log -message "winrm command to allow basic authentication exited with exit code $($winrm.exitcode)"
}
Write-Log -message "Applying AVD Exceptions"
$appName = 'AVD-Exceptions'
$SecFileContent = @'
[Unicode]
Unicode=yes
[Version]
signature="$CHICAGO$"
Revision=1
[System Access]
EnableAdminAccount = 1
[Registry Values]
MACHINE\SYSTEM\CurrentControlSet\Control\Lsa\Pku2u\AllowOnlineID=4,1
[Privilege Rights]
SeRemoteInteractiveLogonRight = *S-1-5-32-555,*S-1-5-32-544
SeDenyBatchLogonRight = *S-1-5-32-546
SeDenyNetworkLogonRight = *S-1-5-32-546
SeDenyInteractiveLogonRight = *S-1-5-32-546
SeDenyRemoteInteractiveLogonRight = *S-1-5-32-546
'@
# Applying AVD Exceptions
$SecFile = Join-Path -Path $Script:TempDir -ChildPath "$appName.inf"
$SecFileContent | Out-File -FilePath $SecFile -Encoding unicode
# Remove Setting that breaks AVD
Update-LocalGPOTextFile -outfileprefix $appName -Scope 'Computer' -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010002' -RegistryValue 'EccCurves' -Delete -outfileprefix $appName -Verbose
# Remove Firewall Configuration that breaks stand-alone workstation Remote Desktop.
Update-LocalGPOTextFile -outfileprefix $appName -Scope 'Computer' -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile' -RegistryValue 'AllowLocalPolicyMerge' -Delete -outfileprefix $appName -Verbose
Update-LocalGPOTextFile -outfileprefix $appName -Scope 'Computer' -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\WindowsFirewall\PrivateProfile' -RegistryValue 'AllowLocalPolicyMerge' -Delete -outfileprefix $appName -Verbose
Update-LocalGPOTextFile -outfileprefix $appName -Scope 'Computer' -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\WindowsFirewall\PublicProfile' -RegistryValue 'AllowLocalPolicyMerge' -Delete -outfileprefix $appName -Verbose
# Remove Edge Proxy Configuration
Update-LocalGPOTextFile -outfileprefix $appName -Scope 'Computer' -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\Edge' -RegistryValue 'ProxySettings' -Delete -outfileprefix $appName -Verbose
Invoke-LGPO -SearchTerm $appName

#Disable Secondary Logon Service
#WN10-00-000175
Write-Log -message "WN10-00-000175/V-220732: Disabling the Secondary Logon Service."
$Service = 'SecLogon'
$Serviceobject = Get-Service | Where-Object {$_.Name -eq $Service}
If ($Serviceobject) {
    $StartType = $ServiceObject.StartType
    If ($StartType -ne 'Disabled') {
        start-process -FilePath "reg.exe" -ArgumentList "ADD HKLM\System\CurrentControlSet\Services\SecLogon /v Start /d 4 /T REG_DWORD /f" -PassThru -Wait
    }
    If ($ServiceObject.Status -ne 'Stopped') {
        Try {
            Stop-Service $Service -Force
        }
        Catch {
        }
    }
}

<# Enables DEP. If there are bitlocker encrypted volumes, bitlocker is temporarily suspended for this operation
Configure DEP to at least OptOut
V-220726 Windows 10
V-253283 Windows 11
#>
If (-not ($virtualMachine)) {
    Write-Log -message "WN10-00-000145/V-220726: Checking to see if DEP is enabled."
    $nxOutput = BCDEdit /enum '{current}' | Select-string nx
    if (-not($nxOutput -match "OptOut" -or $nxOutput -match "AlwaysOn")) {
        Write-Log -message "DEP is not enabled. Enabling."
        # Determines bitlocker encrypted volumes
        $encryptedVolumes = (Get-BitLockerVolume | Where-Object {$_.ProtectionStatus -eq 'On'}).MountPoint
        if ($encryptedVolumes.Count -gt 0) {
            Write-Log -EventId 1 -Message "Encrypted Drive Found. Suspending encryption temporarily."
            foreach ($volume in $encryptedVolumes) {
                Suspend-BitLocker -MountPoint $volume -RebootCount 0
            }
            Start-Process -Wait -FilePath 'C:\Windows\System32\bcdedit.exe' -ArgumentList '/set "{current}" nx OptOut'
            foreach ($volume in $encryptedVolumes) {
                Resume-BitLocker -MountPoint $volume
                Write-Log -message "Resumed Protection."
            }
        }
        else {
            Start-Process -Wait -FilePath 'C:\Windows\System32\bcdedit.exe' -ArgumentList '/set "{current}" nx OptOut'
        }
    } Else {
        Write-Log -message "DEP is already enabled."
    }

    # WIN10-00-000210/220
    Write-Log -message 'WIN10-00-000210/220: Disabling Bluetooth Radios.'
    Set-BluetoothRadioStatus -BluetoothStatus Off
}
Write-Log -message "Configuring Registry Keys that aren't policy objects."
# WN10-CC-000039
Reg.exe ADD "HKLM\SOFTWARE\Classes\batfile\shell\runasuser" /v SuppressionPolicy /d 4096 /t REG_DWORD /f
Reg.exe ADD "HKLM\SOFTWARE\Classes\cmdfile\shell\runasuser" /v SuppressionPolicy /d 4096 /t REG_DWORD /f
Reg.exe ADD "HKLM\SOFTWARE\Classes\exefile\shell\runasuser" /v SuppressionPolicy /d 4096 /t REG_DWORD /f
Reg.exe ADD "HKLM\SOFTWARE\Classes\mscfile\shell\runasuser" /v SuppressionPolicy /d 4096 /t REG_DWORD /f

# CVE-2013-3900
Write-Log -message "CVE-2013-3900: Mitigating PE Installation risks."
Reg.exe ADD "HKLM\SOFTWARE\Wow6432Node\Microsoft\Cryptography\Wintrust\Config" /v EnableCertPaddingCheck /d 1 /t REG_DWORD /f
Reg.exe ADD "HKLM\SOFTWARE\Microsoft\Cryptography\Wintrust\Config" /v EnableCertPaddingCheck /d 1 /t REG_DWORD /f

Remove-Item -Path $Script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Log -message "Ending '$PSCommandPath'."