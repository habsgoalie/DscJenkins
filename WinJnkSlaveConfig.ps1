Configuration WinJnkSlaveConfig
{

    Import-DscResource -ModuleName cChoco
    Import-DscResource -Module xCredSSP
    Import-DscResource -Module cNtfsAccessControl

    $Cred = Get-AutomationPSCredential -Name "adminuser"

    Node JenkinsSlave {
        cChocoInstaller installChoco
        {
            InstallDir = "C:\choco"
        }

        cChocoPackageInstaller installGit 
        {            
            Name = "git" 
            DependsOn = "[cChocoInstaller]installChoco"
        }

        cChocoPackageInstaller installJava 
        {            
            Name = "jre8" 
            DependsOn = "[cChocoInstaller]installChoco"
        }

        file installJenkins
        {
            Ensure = "Present"
            Type = "Directory"
            Recurse = $true
            SourcePath = "\\myfileserver.domain.local\Jenkins"
            DestinationPath = "C:\Jenkins"
        }
        
        windowsFeature dotNet35Features
        {
            Ensure = "Present"
            Name = "NET-Framework-Core"
            IncludeAllSubFeature = $True
        }
        script configureJenkinsService
        {
            SetScript = {
                & 'C:\Jenkins\jenkins.exe' install
                }
            TestScript = {
                $Jenkins = Get-Service jenkins -ErrorAction SilentlyContinue
                if($Jenkins.Name -like "jenkins" -and $Jenkins.Status -like "Running"){
                    Write-Verbose "Jenkins Service is installed and running"
                    Return $True
                }
                else{
                    Write-Verbose "Jenkins Slave not running"
                    Return $False
                }
            }
            GetScript = {
                #Do Nothing
            }
            DependsOn = "[file]installJenkins"
        }

        Service jenkinsService
        {
            Ensure = "Present"
            Name = "jenkins"
            StartupType = "Automatic"
            State = "Running"
            DependsOn = "[script]configureJenkinsService"
        }

        cNtfsPermissionEntry jenkinsPerm
        {
            Ensure = 'Present'
            Path = "C:\Jenkins"
            Principal = 'BUILTIN\Users'
            AccessControlInformation = @(
                cNtfsAccessControlInformation
                {
                    AccessControlType = 'Allow'
                    FileSystemRights = 'Modify'
                    Inheritance = 'ThisFolderSubfoldersAndFiles'
                    NoPropagateInherit = $false
                }
            )
            DependsOn = '[file]installJenkins'
        }

        xCredSSP Server
        {
            Ensure = "Present"
            Role = "Server"
        }
        xCredSSP Client
        {
            Ensure = "Present"
            Role = "Client"
            DelegateComputers = "*.domain.local"
        }

        Group addToAdministrators
        {
                GroupName = "Administrators"
                Ensure = "Present"
                MembersToInclude = "domain\svc_user"
                Credential = $Cred
        }
    }
}