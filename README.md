# PowerRunAs

This module allows you to run a process (defaulting to PowerShell) as a different user by providing a known username and password. By default, the standard output (stdout), standard error (stderr), and standard input (stdin) are attached to the current console of the caller.

This module can also be used as standalone script.

## Installation

### As a Module

```powershell
Install-Module -Name PowerRunAs
Import-Module -Name PowerRunAs
```

### As a Script

```powershell
IEX (Get-Content .\PowerRunAs.psm1 -Raw)
```

Or

```powershell
IEX (New-Object Net.WebClient).DownloadString('<protocol>://<host>:<port>/<uri>/PowerRunAs.psm1')
```

Or Invoke-🧠

## Usage

| Parameter          | Type             | Default    | Description  |
|--------------------|------------------|------------|--------------|
| Username (*)       | String           | None       | An existing Microsoft Windows local user account.  |
| Password (*)       | String           | None       | Password of specified user account. |
| Domain             | String           | None       | specify the domain of the user account under which the new process is to be started. |
| Application        | String           | powershell.exe | Application to be executed in the context of a different user. |
| Argument           | String           | None       | An optional argument to be passed to the application. |
| Detach             | Switch           | False      | If present, stdout, stdin, and stderr will not be connected to the current caller's console. The process will run in a detached state and will be visible. |

`*` = Mandatory Options

### Example

![Example](images/example.png)

```powershell
net user darkcodersc mypassword /add
```

```powershell
# Launch a new instance of PowerShell as the user darkcodersc in the caller's console (attached).
Invoke-RunAs -Username "darkcodersc" -Password "mypassword"

# Launch a visible notepad as the user darkcodersc (dettached)
Invoke-RunAs -Username "darkcodersc" -Password "mypassword" -Application "notepad.exe" -Detach
```