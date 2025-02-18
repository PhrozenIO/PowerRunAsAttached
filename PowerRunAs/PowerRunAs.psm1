# ----------------------------------------------------------------------------------- #
#                                                                                     #
#    .Developer                                                                       #
#        Jean-Pierre LESUEUR (@DarkCoderSc)                                           #
#        https://www.twitter.com/darkcodersc                                          #
#        https://github.com/PhrozenIO                                                 #
#        https://github.com/DarkCoderSc                                               #
#        www.phrozen.io                                                               #
#        jplesueur@phrozen.io                                                         #
#        PHROZEN                                                                      #
#    .License                                                                         #
#        Apache License                                                               #
#        Version 2.0, January 2004                                                    #
#        http://www.apache.org/licenses/                                              #
#    .Disclaimer                                                                      #
#        This script is provided "as is", without warranty of any kind, express or    #
#        implied, including but not limited to the warranties of merchantability,     #
#        fitness for a particular purpose and noninfringement. In no event shall the  #
#        authors or copyright holders be liable for any claim, damages or other       #
#        liability, whether in an action of contract, tort or otherwise, arising      #
#        from, out of or in connection with the software or the use or other dealings #
#        in the software.                                                             #
#                                                                                     #
# ----------------------------------------------------------------------------------- #

$global:sharedData = @{
    "StdErrTick" = 0
}

function Add-StdHandler
{
    param (
        [Parameter(Mandatory=$true)]
        [System.IO.StreamReader] $Stream,

        [bool] $StandardErrorFlag = $false
    )

    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.Open()

    $runspace.SessionStateProxy.SetVariable("SharedData", $global:sharedData)
    $runspace.SessionStateProxy.SetVariable("hostUI", $host.UI)
    $runspace.SessionStateProxy.SetVariable("Stream", $Stream);
    $runspace.SessionStateProxy.SetVariable("StandardErrorFlag", $StandardErrorFlag);

    $powershell = [PowerShell]::Create().AddScript({
        try
        {
            $sbData = New-Object System.Text.StringBuilder

            while ($true)
            {
                $null = $sbData.Append([char]$Stream.BaseStream.ReadByte())

                if ((-not $StandardErrorFlag) -and (([Environment]::TickCount - $SharedData.StdErrTick) -le 150))
                {
                    Start-Sleep -Milliseconds 100

                    continue
                }

                if ($StandardErrorFlag)
                {
                    $SharedData.StdErrTick = [Environment]::TickCount
                }

                $hostUI.Write($sbData.ToString())
                $sbData.Clear()
            }
        }
        catch {
            break
        }
    })

    $powershell.Runspace = $runspace

    $null = $powershell.BeginInvoke()

    return $runspace
}

function Invoke-RunAs
{
    param (
        [Parameter(Mandatory=$true)]
        [string] $Username,

        [Parameter(Mandatory=$true)]
        [string] $Password,

        [string] $Application = "powershell.exe",
        [string] $Argument = "",
        [string] $Domain = "",
        [switch] $Detach
    )

    $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Application
    $startInfo.WorkingDirectory = $env:SystemRoot
    $startInfo.UseShellExecute = $false
    $startInfo.Domain = $Domain
    $startInfo.Username = $Username
    $startInfo.Password = $securePassword
    $startInfo.Arguments = $Argument

    if (-not $Detach)
    {
        $startInfo.RedirectStandardError = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardInput = $true
        $startInfo.CreateNoWindow = $true
    }

    $proc = New-Object System.Diagnostics.Process

    $proc.StartInfo = $startInfo

    $null = $proc.Start()

    if (-not $Detach)
    {
        $runspaces = @()
        try
        {
            $runspaces += Add-StdHandler -Stream $proc.StandardError -StandardErrorFlag $true
            $runspaces += Add-StdHandler -Stream $proc.StandardOutput

            while (-not $proc.HasExited)
            {
                $userInput = Read-Host

                $proc.StandardInput.WriteLine($userInput)

                if ($userInput.ToLower() -eq "exit")
                {
                    break
                }
            }
        }
        finally
        {
            foreach ($runspace in $runspaces)
            {
                $runspace.Close()
                $runspace.Dispose()
            }
        }
    }
}

try {
    Export-ModuleMember -Function Invoke-RunAs
} catch {}
