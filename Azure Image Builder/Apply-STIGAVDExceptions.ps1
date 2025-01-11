[string]$Script:LogDir = "$env:SystemRoot\Logs\Configuration"
[string]$ScriptName = "Apply-STIG-AVD-Exceptions"
[string]$Log = Join-Path -Path $Script:LogDir -ChildPath "$ScriptName.log"
[string]$Script:TempDir = Join-Path -Path $env:Temp -ChildPath $ScriptName

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
        [string]$outputDir = "$TempDir",
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

        Write-Verbose "${CmdletName}: Adding registry information to '$outfile' for LGPO.exe"
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

Function Invoke-LGPO {
    [CmdletBinding()]
    Param (
        [string]$InputDir = "$Script:TempDir",
        [string]$SearchTerm
    )
    Begin {
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
    }
    Process {
        Write-Verbose "${CmdletName}: Gathering Registry text files for LGPO from '$InputDir'"
        If ($SearchTerm) {
            $InputFiles = Get-ChildItem -Path $InputDir -Filter "$SearchTerm*.txt"
        }
        Else {
            $InputFiles = Get-ChildItem -Path $InputDir -Filter '*.txt'
        }
        ForEach ($RegistryFile in $inputFiles) {
            $TxtFilePath = $RegistryFile.FullName
            Write-Verbose "${CmdletName}: Now applying settings from '$txtFilePath' to Local Group Policy via LGPO.exe."
            $lgporesult = Start-Process -FilePath 'lgpo.exe' -ArgumentList "/t `"$TxtFilePath`"" -Wait -PassThru
            Write-Verbose "${CmdletName}: LGPO exitcode: '$($lgporesult.exitcode)'"
        }
        Write-Verbose "${CmdletName}: Gathering Security Templates files for LGPO from '$InputDir'"
        $ConfigFile = Get-ChildItem -Path $InputDir -Filter '*.inf'
        If ($ConfigFile) {
            $ConfigFile = $ConfigFile.FullName
            Write-Verbose "${CmdletName}: Now applying security settings from '$ConfigFile' to Local Security Policy via LGPO.exe."
            $lgporesult = Start-Process -FilePath 'lgpo.exe' -ArgumentList "/s `"$ConfigFile`"" -Wait -PassThru
            Write-Verbose "${CmdletName}: LGPO exitcode: '$($lgporesult.exitcode)'"
        }
    }
    End {
    }
}

#endregion Functions

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

If (-not (Test-Path $env:SystemRoot\Logs)) {
    New-Item -Path $env:SystemRoot -Name 'Logs' -ItemType Directory -Force
}
If (-not (Test-Path $Script:LogDir)) {
    New-Item -Path "$env:SystemRoot\Logs" -Name 'Configuration' -ItemType Directory -Force
}
If (-not (Test-Path $Script:TempDir)) {
    New-Item -Path $Script:TempDir -ItemType Directory -Force
}
Start-Transcript -Path $Log -Force -IncludeInvocationHeader

Write-Output "Checking for lgpo.exe in '$env:SystemRoot\system32'."

If (-not(Test-Path -Path "$env:SystemRoot\System32\Lgpo.exe")) {
    $LGPOZip = Join-Path -Path $PSScriptRoot -ChildPath 'LGPO.zip'
    If (Test-Path $LGPOZip) {
        Write-Log -category Info -message "Expanding '$LGPOZip' to '$Script:TempDir'."
        Expand-Archive -path "$LGPOZip" -DestinationPath $Script:TempDir -force
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
        Remove-Item $fileLGPODownload -Force
        $fileLGPO = (Get-ChildItem -Path $outputDir -file -Filter 'lgpo.exe' -Recurse)[0].FullName
        Write-Output "Copying `"$fileLGPO`" to System32"
        Copy-Item -Path $fileLGPO -Destination "$env:SystemRoot\System32" -Force
        Remove-Item -Path $outputDir -Recurse -Force
    }
}

If (Test-Path -Path "$env:SystemRoot\System32\Lgpo.exe") {

    $SecFileContent | Out-File -FilePath "$Script:TempDir\STIGExceptions.inf" -Encoding unicode

    $appName = 'STIG_Exceptions'

    # Remove Setting that breaks AVD
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010002' -RegistryValue 'EccCurves' -Delete -outfileprefix $appName -Verbose
    # Remove Firewall Configuration that breaks stand-alone workstation Remote Desktop.
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile' -RegistryValue 'AllowLocalPolicyMerge' -Delete -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\WindowsFirewall\PrivateProfile' -RegistryValue 'AllowLocalPolicyMerge' -Delete -outfileprefix $appName -Verbose
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\WindowsFirewall\PublicProfile' -RegistryValue 'AllowLocalPolicyMerge' -Delete -outfileprefix $appName -Verbose
    # Remove Edge Proxy Configuration
    Update-LocalGPOTextFile -Scope 'Computer' -RegistryKeyPath 'SOFTWARE\Policies\Microsoft\Edge' -RegistryValue 'ProxySettings' -Delete -outfileprefix $appName -Verbose
    
    Invoke-LGPO -Verbose
}
Else {
    Write-Error "Unable to configure local policy with lgpo tool because it was not found and could not be downloaded."
    Stop-Transcript
    Exit 2
}

Stop-Transcript