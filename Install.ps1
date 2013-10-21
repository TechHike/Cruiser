
function Install-Cruiser(){

    $ModulePath = $Env:PSModulePath -split ";" | Select -Index 0
	$BaseUrl = 'https://bitbucket.org/TechHike/cruiser/raw/default/Cruiser'

	New-Item ($ModulePath + "\Cruiser\") -ItemType Directory -Force | Out-Null
    Write-Host "Downloading Cruiser from $BaseUrl"
	
	$InstallFiles = @('Cruiser.psm1', 'Cruiser.psd1', 'Cruiser.ps1', 'Cruiser-History.xslt', 'Build.ps1')
	foreach ($File in $InstallFiles) {
		$RemoteFile = ("{0}/$File" -f $BaseUrl, $File)
		$LocalPath = ("{0}\Cruiser\{1}" -f $ModulePath, $File)
		Write-Host "Installing $LocalPath"
	    (New-Object Net.WebClient).DownloadFile($RemoteFile, $LocalPath)  
	}	

    $ExPolicy  = (Get-ExecutionPolicy)

	if ($ExPolicy -eq "Restricted"){
	
        Write-Warning @"
Your execution policy is $executionPolicy, this means you will not be able import or use any scripts including modules.
To fix this change you execution policy to something like RemoteSigned.

        PS> Set-ExecutionPolicy RemoteSigned

For more information execute:
        
        PS> Get-Help about_execution_policies

"@

    } else {
	
		Write-Host "Cruiser installed." -ForegroundColor Green
        Import-Module Cruiser
		
    }    
}

Install-Cruiser