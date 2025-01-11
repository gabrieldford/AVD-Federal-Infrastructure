<#
.SYNOPSIS
    This script uses the local group policy object tool (lgpo.exe) to apply the applicable DISA STIGs GPOs either downloaded directly from CyberCom or
    the files are contained with this script in the root of a folder.
.NOTES
    To use this script offline, download the lgpo tool from 'https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/LGPO.zip' and extract 'lpgo.exe'
    to the root of the folder where this script is located. Then download the latest STIG GPOs ZIP from 'https://public.cyber.mil/stigs/gpo' and copy the zip file to the root
    of the folder where this script is located.

    This script not only applies the GPO objects but it also applies some registry settings and other mitigations. Ensure that these other items still apply through the
    lifecycle of the script.
#>

#region Initialization

$Script:FullName = $MyInvocation.MyCommand.Path
$Script:File = $MyInvocation.MyCommand.Name
$Script:Name=[System.IO.Path]::GetFileNameWithoutExtension($Script:File)
$virtualMachine = Get-WmiObject -Class Win32_ComputerSystem | Where-Object {$_.Model -match 'Virtual'}
$osCaption = (Get-WmiObject -Class Win32_OperatingSystem).caption
If ($osCaption -match 'Windows 11') { $osVersion = 11 } Else { $osVersion = 10 }

[String]$Script:LogDir = "$($env:SystemRoot)\Logs\Configuration"
If (-not(Test-Path -Path $Script:LogDir)) {
    New-Item -Path "$($env:SystemRoot)\Logs" -Name Configuration -ItemType Dir -Force
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
        Write-Verbose "Starting ${CmdletName} with the following parameters: $PSBoundParameters"
    }
    Process {

        $start_time = Get-Date

        If (!$OutputFileName) {
            Write-Verbose "${CmdletName}: No OutputFileName specified. Trying to get file name from URL."
            If ((split-path -path $Url -leaf).Contains('.')) {

                $OutputFileName = split-path -path $url -leaf
                Write-Verbose "${CmdletName}: Url contains file name - '$OutputFileName'."
            }
            Else {
                Write-Verbose "${CmdletName}: Url does not contain file name. Trying 'Location' Response Header."
                $request = [System.Net.WebRequest]::Create($url)
                $request.AllowAutoRedirect=$false
                $response=$request.GetResponse()
                $Location = $response.GetResponseHeader("Location")
                If ($Location) {
                    $OutputFileName = [System.IO.Path]::GetFileName($Location)
                    Write-Verbose "${CmdletName}: File Name from 'Location' Response Header is '$OutputFileName'."
                }
                Else {
                    Write-Verbose "${CmdletName}: No 'Location' Response Header returned. Trying 'Content-Disposition' Response Header."
                    $result = Invoke-WebRequest -Method GET -Uri $Url -UseBasicParsing
                    $contentDisposition = $result.Headers.'Content-Disposition'
                    If ($contentDisposition) {
                        $OutputFileName = $contentDisposition.Split("=")[1].Replace("`"","")
                        Write-Verbose "${CmdletName}: File Name from 'Content-Disposition' Response Header is '$OutputFileName'."
                    }
                }
            }
        }

        If ($OutputFileName) { 
            $wc = New-Object System.Net.WebClient
            $OutputFile = Join-Path $OutputDirectory $OutputFileName
            Write-Verbose "${CmdletName}: Downloading file at '$url' to '$OutputFile'."
            Try {
                $wc.DownloadFile($url, $OutputFile)
                $time = (Get-Date).Subtract($start_time).Seconds
                
                Write-Verbose "${CmdletName}: Time taken: '$time' seconds."
                if (Test-Path -Path $outputfile) {
                    $totalSize = (Get-Item $outputfile).Length / 1MB
                    Write-Verbose "${CmdletName}: Download was successful. Final file size: '$totalsize' mb"
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
        Write-Verbose "Ending ${CmdletName}"
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
        Write-Verbose "${CmdletName}: Starting ${CmdletName} with the following parameters: $PSBoundParameters"
    }
    Process {

        Try {
            Write-Verbose -message "${CmdletName}: Now extracting download URL from '$Url'."
            $HTML = Invoke-WebRequest -Uri $Url -UseBasicParsing
            $Links = $HTML.Links
            $ahref = $null
            $ahref=@()
            $ahref = ($Links | Where-Object {$_.href -like "*$searchstring*"}).href
            If ($ahref.count -eq 0 -or $null -eq $ahref) {
                $ahref = ($Links | Where-Object {$_.OuterHTML -like "*$searchstring*"}).href
            }
            If ($ahref.Count -eq 1) {
                Write-Verbose -Message "${CmdletName}: Download URL = '$ahref'"
                $ahref

            }
            Elseif ($ahref.Count -gt 1) {
                Write-Verbose -Message "${CmdletName}: Download URL = '$($ahref[0])'"
                $ahref[0]
            }
        }
        Catch {
            Write-Error "${CmdletName}: Error Downloading HTML and determining link for download."
        }
    }
    End {
        Write-Verbose -Message "${CmdletName}: Ending ${CmdletName}"
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

#endregion

#region Main

New-Log -Path $Script:LogDir
Write-Log -category Info -message "Starting '$PSCommandPath'."

If (-not(Test-Path -Path "$env:SystemRoot\System32\Lgpo.exe")) {
    $LGPOZip = Join-Path -Path $PSScriptRoot -ChildPath 'LGPO.zip'
    If (Test-Path $LGPOZip) {
        Write-Log -category Info -message "Expanding '$LGPO' to '$Script:TempDir'."
        expand-archive -path $LGPOZip -DestinationPath $Script:TempDir -force
        $algpoexe = Get-ChildItem -Path $Script:TempDir -filter 'lgpo.exe' -recurse
        If ($algpoexe.count -gt 0) {
            $fileLGPO = $algpoexe[0].FullName
            Write-Log -category Info -message "Copying '$fileLGPO' to '$env:SystemRoot\system32'."
            Copy-Item -Path $fileLGPO -Destination "$env:SystemRoot\System32" -force        
        }
    } Else {
        $urlLGPO = 'https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/LGPO.zip'
        $LGPOZip = Get-InternetFile -Url $urlLGPO -OutputDirectory $Script:TempDir
        $outputDir = Join-Path $Script:TempDir -ChildPath 'LGPO'
        Expand-Archive -Path $LGPOZip -DestinationPath $outputDir
        Remove-Item $LGPOZip -Force
        $fileLGPO = (Get-ChildItem -Path $outputDir -file -Filter 'lgpo.exe' -Recurse)[0].FullName
        Write-Output "Copying `"$fileLGPO`" to System32"
        Copy-Item -Path $fileLGPO -Destination "$env:SystemRoot\System32" -Force
        Remove-Item -Path $outputDir -Recurse -Force
    }
}

$stigZip = Join-Path -Path $PSScriptRoot -ChildPath 'STIGs.zip'
If (-not (Test-Path $stigZip)) {
    #Download the STIG GPOs
    $uriSTIGs = 'https://public.cyber.mil/stigs/gpo'
    $uriGPODownload = Get-InternetUrl -Url $uriSTIGs -searchstring 'GPOs'
    Write-Output "Downloading STIG GPOs from `"$uriGPODownload`"."
    If ($uriGPODownload) {
        $stigZip = Get-InternetFile -url $uriGPODownload -OutputDirectory $Script:TempDir
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