function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.Boolean] $RunConfigWizard,
        
        [parameter(Mandatory = $true)]
        [ValidateSet("mon","tue","wed","thu","fri","sat","sun")]
        [System.String[]] $DatabaseUpgradeDays,
        
        [parameter(Mandatory = $true)]
        [System.String] $DatabaseUpgradeTime,
        
        [parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential] $InstallAccount
    )

    Write-Verbose -Message "Getting status of Configuration Wizard"

    # Check which version of SharePoint is installed
    if ((Get-SPDSCInstalledProductVersion).FileMajorPart -eq 15)
    {
        $wssRegKey ="hklm:SOFTWARE\Microsoft\Shared Tools\Web Server Extensions\15.0\WSS"
    } else {
        $wssRegKey ="hklm:SOFTWARE\Microsoft\Shared Tools\Web Server Extensions\16.0\WSS"
    }

    # Read LanguagePackInstalled and SetupType registry keys
    $languagePackInstalled = Get-SPDSCRegistryKey $wssRegKey "LanguagePackInstalled"
    $setupType = Get-SPDSCRegistryKey $wssRegKey "SetupType"

    # Determine if LanguagePackInstalled=1 or SetupType=B2B_Upgrade. If so, the Config Wizard is required
    if (($languagePackInstalled -eq 1) -or ($setupType -eq "B2B_UPGRADE"))
    {
        return @{
            RunConfigWizard = $true
            DatabaseUpgradeDays = $DatabaseUpgradeDays
            DatabaseUpgradeTime = $DatabaseUpgradeTime
        }
    } else {
        return @{
            RunConfigWizard = $false
            DatabaseUpgradeDays = $DatabaseUpgradeDays
            DatabaseUpgradeTime = $DatabaseUpgradeTime
        }
    }
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.Boolean] $RunConfigWizard,
        
        [parameter(Mandatory = $true)]
        [ValidateSet("mon","tue","wed","thu","fri","sat","sun")]
        [System.String[]] $DatabaseUpgradeDays,
        
        [parameter(Mandatory = $true)]
        [System.String] $DatabaseUpgradeTime,
        
        [parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential] $InstallAccount
    )

    Write-Verbose -Message "Testing status of Configuration Wizard"

    if ($DatabaseUpgradeTime)
    {
        #check if current time is in window
        if ($true)
        {
            #check 
        }
        else
        {
            Write-Verbose "Current time is outside of time window, skipping the Configuration Wizard"
            return
        }
    }


    $now = Get-Date
    if ($DatabaseUpgradeDays)
    {
        # DatabaseUpgradeDays parameter exists, check if current day is specified
        $currentDayOfWeek = $now.DayOfWeek.ToString().ToLower().Substring(0,3)

        if ($DatabaseUpgradeDays -contains $currentDayOfWeek)
        {
            Write-Verbose "Current day is present in the parameter DatabaseUpgradeDays. Configuration wizard can be run today."
        }
        else
        {
            Write-Verbose "Current day is not present in the parameter DatabaseUpgradeDays, skipping the Configuration Wizard"
            return
        }
    }
    else
    {
        Write-Verbose "No DatabaseUpgradeDays specified, Configuration Wizard can be ran on any day."
    }

    # Check if DatabaseUpdateTime parameter exists
    if ($DatabaseUpgradeTime)
    {
        # Check if current time is inside of time window
        $upgradeTimes = $DatabaseUpgradeTime.Split(" ")
        $starttime = 0
        $endtime = 0

        if ($upgradeTimes.Count -ne 3)
        {
            throw "Time window incorrectly formatted."
        }
        else
        {
            if ([datetime]::TryParse($upgradeTimes[0],[ref]$starttime) -ne $true)
            {
                throw "Error converting start time"
            }

            if ([datetime]::TryParse($upgradeTimes[2],[ref]$endtime) -ne $true)
            {
                throw "Error converting end time"
            }

            if ($starttime -gt $endtime)
            {
                throw "Error: Start time cannot be larger than end time"
            }
        }

        if (($starttime -lt $now) -and ($endtime -gt $now))
        {
            Write-Verbose "Current time is inside of the window specified in DatabaseUpgradeTime. Starting wizard"
        }
        else
        {
            Write-Verbose "Current time is outside of the window specified in DatabaseUpgradeTime, skipping the Configuration Wizard"
            return
        }
    }
    else
    {
        Write-Verbose "No DatabaseUpgradeTime specified, Configuration Wizard can be ran at any time. Starting wizard."
    }

    if ($RunConfigWizard -eq $false)
    {
        Write-Verbose -Message "RunConfigWizard is set to False, so running the Configuration Wizard is not required"
        return
    }

    # Check which version of SharePoint is installed
    if ((Get-SPDSCInstalledProductVersion).FileMajorPart -eq 15)
    {
        $binaryDir = Join-Path $env:CommonProgramFiles "Microsoft Shared\Web Server Extensions\15\BIN"
    } else {
        $binaryDir = Join-Path $env:CommonProgramFiles "Microsoft Shared\Web Server Extensions\16\BIN"
    }

    # Start wizard
    Write-Verbose -Message "Starting Configuration Wizard"
    $psconfigExe = Join-Path -Path $binaryDir -ChildPath "setup.exe"
    $psconfig = Start-Process -FilePath $psconfigExe -ArgumentList "-cmd upgrade -inplace b2b -wait -force" -Wait -PassThru

    switch ($psconfig.ExitCode)
    {
        0 {  
            Write-Verbose -Message "SharePoint Post Setup Configuration Wizard ran successfully"
        }
        Default {
            throw "SharePoint Post Setup Configuration Wizard failed, exit code was $($setup.ExitCode)"
        }
    }
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.Boolean] $RunConfigWizard,
        
        [parameter(Mandatory = $true)]
        [ValidateSet("mon","tue","wed","thu","fri","sat","sun")]
        [System.String[]] $DatabaseUpgradeDays,
        
        [parameter(Mandatory = $true)]
        [System.String] $DatabaseUpgradeTime,
        
        [parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential] $InstallAccount
    )

    if ($RunConfigWizard -eq $false)
    {
        Write-Verbose -Message "RunConfigWizard is set to False, so running the Configuration Wizard is not required"
        return $true
    }

    Write-Verbose -Message "Testing status of Configuration Wizard"

    $currentValues = Get-TargetResource @PSBoundParameters

    return -not($currentValues.RunConfigWizard)
}

Export-ModuleMember -Function *-TargetResource

<#
    .SYNOPSIS
        Checks if the specified key of the registry exists and if so returns the specified value. 

    .PARAMETER Key
        Registry key in which the value exists

    .PARAMETER Value
        Registry value to return

    .EXAMPLE
        Get-SPDSCRegistryKey -Key "hklm:SOFTWARE\Microsoft\Shared Tools\Web Server Extensions\15.0\WSS" -Value "LanguagePackInstalled"
#>
Function Get-SPDSCRegistryKey() {
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Key,

        [parameter(Mandatory = $true)]
        [System.String]
        $Value
    )

    if ((Test-Path $Key) -eq $true)
    {
        $regKey = Get-ItemProperty -LiteralPath $Key
        return $regKey.$Value
    } else {
        throw "Specified registry key $Key could not be found."
    }    
}