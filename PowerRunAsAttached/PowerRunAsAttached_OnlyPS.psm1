<#-------------------------------------------------------------------------------
    .Developer
        Jean-Pierre LESUEUR (@DarkCoderSc)
        https://www.twitter.com/darkcodersc
        https://github.com/DarkCoderSc
        www.phrozen.io
        jplesueur@phrozen.io
        PHROZEN
    .License
        Apache License
        Version 2.0, January 2004
        http://www.apache.org/licenses/
-------------------------------------------------------------------------------#>   

$global:CriticalSection = [HashTable]::Synchronized(@{
    Host = $host
    StdErrTick = 0
})

function Add-StdHandler
{     
    param (
        [Parameter(Mandatory=$true)]
        [System.IO.StreamReader] $Stream,

        [bool] $StandardErrorFlag = $false
    )

    $stdRunspace = [RunspaceFactory]::CreateRunspace()
    $stdRunspace.ThreadOptions = "ReuseThread"
    $stdRunspace.ApartmentState = "STA"
    $stdRunspace.Open() 

    $syncObjects = [HashTable]::Synchronized(@{})

    $stdRunspace.SessionStateProxy.SetVariable("CriticalSection", $global:CriticalSection)
    $stdRunspace.SessionStateProxy.SetVariable("Stream", $Stream);
    $stdRunspace.SessionStateProxy.SetVariable("StandardErrorFlag", $StandardErrorFlag);

    $psStdInstance = [PowerShell]::Create().AddScript({     
        try
        {           
            while ($true)
            {                            
                if ((-not $StandardErrorFlag) -and (([Environment]::TickCount - $CriticalSection.StdErrTick) -le 100))
                {
                    Start-Sleep -Milliseconds 200
                    continue
                }      

                if ($StandardErrorFlag)
                {
                    $CriticalSection.StdErrTick = [Environment]::TickCount # Update
                }

                $CriticalSection.host.UI.Write([char]$Stream.BaseStream.ReadByte())                          
            }
        } catch { break }            
    })

    $psStdInstance.Runspace = $stdRunspace

    $psStdInstance.BeginInvoke() | Out-Null

    return $stdRunspace  
}

function Invoke-RunAsAttached
{
    param (
        [Parameter(Mandatory=$true)]
        [string] $Username,
        [Parameter(Mandatory=$true)]
        [string] $Password,
        [string] $Domain = ""
    )

    $protectedPassword = ConvertTo-SecureString $Password -AsPlainText -Force

    $processInformation = New-Object System.Diagnostics.ProcessStartInfo
    $processInformation.FileName = "cmd.exe"
    $processInformation.WorkingDirectory = $env:SystemRoot      
    $processInformation.UseShellExecute = $false    
    $processInformation.RedirectStandardError = $true
    $processInformation.RedirectStandardOutput = $true
    $processInformation.RedirectStandardInput = $true
    $processInformation.Domain = $Domain
    $processInformation.Username = $Username
    $processInformation.Password = $protectedPassword
    $processInformation.Arguments = ""
    $processInformation.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process

    $proc.StartInfo = $processInformation

    $procResult = $proc.Start()

    if (-not $procResult)
    {
        return
    }    
    
    $psInstances = New-Object System.Collections.ArrayList
    try
    {
        $psInstance = (Add-StdHandler -Stream $proc.StandardError -StandardErrorFlag $true)
        if ($psInstance -eq $null)
        {
            throw "Could not create ""StandardError"" handler."
        }

        $psInstances.Add($psInstance) | Out-Null

        $psInstance = (Add-StdHandler -Stream $proc.StandardOutput)
        if ($psInstance -eq $null)
        {
            throw "Could not create ""StandardOutpout"" handler."
        }

        $psInstances.Add($psInstance) | Out-Null

        while (-not $proc.HasExited)
        {                               
            $proc.StandardInput.WriteLine((Read-Host))
        }
    }
    finally
    {
        foreach ($psInstance in $psInstances)
        {
            $psInstance.Close()
            $psInstance.Dispose()
        }
    }
}

try {  
    Export-ModuleMember -Function Invoke-RunAsAttached
} catch {}
