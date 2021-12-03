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

Add-Type -Language CSharp -TypeDefinition @'
    using System;
    using System.IO;
    using System.Net;
    using System.Diagnostics;    
    using System.Threading;
    using System.Security;

    public class RunAsAttached
	{
        private string Username = "";
        private SecureString SecurePassword = null;
        private string Domain = "";
        private Process Proc = null;

        private readonly object CriticalSection = new object();

        public void ReadStdThread(Process proc, bool stdErr = false) 
        {        
            StreamReader reader = null;
            if (stdErr)
            {
                reader = proc.StandardError;
            } 
            else 
            {
                reader = proc.StandardOutput;
            }

            char[] buffer = new char[1024];

            while (!proc.HasExited) 
            {
                int read = reader.ReadAsync(buffer, 0, buffer.Length).Result;

                lock (this.CriticalSection) 
                {
                    if (stdErr) {Console.ForegroundColor = ConsoleColor.Red;}
                    Console.Write(buffer, 0, read);
                    if (stdErr) {Console.ResetColor();}
                }
            }            
        }

        public RunAsAttached(string username, string password, string domain = "") 
        {
			this.Username = username;            
            this.Domain = domain;

            this.SecurePassword = new NetworkCredential("", password).SecurePassword;
		}

        public void Spawn() 
        {
            ProcessStartInfo processInformation = new ProcessStartInfo();                    
            
            processInformation.FileName = "cmd.exe";
            processInformation.WorkingDirectory = Environment.GetEnvironmentVariable("SystemRoot");
            processInformation.UseShellExecute = false;
            processInformation.RedirectStandardError = true;
            processInformation.RedirectStandardOutput = true;
            processInformation.RedirectStandardInput = true;
            processInformation.Domain = this.Domain;
            processInformation.UserName = this.Username;
            processInformation.Password = this.SecurePassword;
            processInformation.Arguments = "";
            processInformation.CreateNoWindow = true;

            Console.WriteLine(processInformation.FileName);

            this.Proc = new Process();

            this.Proc.StartInfo = processInformation;
        
            this.Proc.Start();

            Thread stdOutReader = new Thread(() => this.ReadStdThread(this.Proc));
            Thread stdErrReader = new Thread(() => this.ReadStdThread(this.Proc, true));
          
            stdOutReader.Start();
            stdErrReader.Start();

            while (!this.Proc.HasExited) 
            {
                this.Proc.StandardInput.WriteLine(Console.ReadLine());
            }

            Console.WriteLine("...");
        }
    }
'@ 

function Invoke-RunAsAttached
{
    param (
        [Parameter(Mandatory=$true)]
        [string] $Username,
        [Parameter(Mandatory=$true)]
        [string] $Password,
        [string] $Domain = ""
    )

    
    $runAsAttached = New-Object -TypeName RunAsAttached -ArgumentList $Username, $Password, $Domain    

    $runAsAttached.Spawn()
}

try {  
    Export-ModuleMember -Function Invoke-RunAsAttached
} catch {}
