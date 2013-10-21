param([switch]$Server, [switch]$Background)

$global:CruiserInstallDirectory = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)


function Start-Cruiser {
	param([switch]$Server, [switch]$Background)

	Import-Module PSCX 

	$script:global = @{
		"install_dir" = $global:CruiserInstallDirectory;
		"status_xslt_path" = ("{0}\Cruiser-History.xslt" -f $global:CruiserInstallDirectory);
	}
	
	if ($Background) {
		Stop-Cruiser

		Write-Host $Server
		
		Start-Job -Name "Cruiser" -ScriptBlock { 
			param([string]$CruiserInstallDirectoryJob, [string]$PWDJob, [bool]$ServerJob)
			. "$CruiserInstallDirectoryJob\Cruiser.ps1"
			Set-Location $PWDJob
			if ($ServerJob) {
				Start-Cruiser -Server
			} else {
				Start-Cruiser
			}
		} -ArgumentList $global:CruiserInstallDirectory, $PWD, $Server.IsPresent 
	} else {
		$ConfigLoaded = Load-Config
		if ($ConfigLoaded) {
			if ($Server) {
				Server
			} else {
				Single
			}
		}
	}

}

function Receive-Cruiser {
	Receive-Job -Name "Cruiser"
}

function Stop-Cruiser {
	Stop-Job -Name Cruiser -ErrorAction SilentlyContinue
	Remove-Job -Name Cruiser -ErrorAction SilentlyContinue
}

function Server {
	Log "System" "Server"
	while ($true) {
		Single
		Wait
		Load-Config | Out-Null
	}
}

function Single {
	foreach ($project in $project_list) {
		#try {
		
		$history.last_poll_start = (Get-Date)
		$history.last_poll_start_str = ("{0:yyyy-MM-dd h:mm tt}" -f $history.last_poll_start)

		$history.next_poll_start = ""
		$history.next_poll_start_str = ""

		if ($project.enable -ne $true) {
			Log "System" ("Skipping {0}, Project disabled." -f $project.name)
			continue
		}
		
		Setup-Build
		Cleanup
		Check-Source
		
		if ($build.enable -ne $true) {
			Log "System" ("Skipping {0}" -f $project.name)
			continue
		}
		
		Get-Source
		Build
		Cleanup
		Finish

		$history.last_poll_end = (Get-Date)
		$history.last_poll_end_str = ("{0:yyyy-MM-dd h:mm tt}" -f $history.last_poll_end)
		
		#} catch [System.Exception] {
	    #	Write-Host $_.Exception.ToString()
		#}
	}
}


function Initialize-Cruiser {
	$config_path = "$CruiserInstallDirectory\Cruiser-Config.ps1"

	(New-Object Net.WebClient).DownloadString("http://psget.net/GetPsGet.ps1") | Invoke-Expression
	Install-Module PSCX

	if (-not (Test-Path "Cruiser-Config.ps1")) {
		Copy-Item $config_path -Destination .  | Out-Null
	}
	if (-not (Test-Path "Output")) {
		New-Item "Output" -ItemType Directory | Out-Null
	}
	if (-not (Test-Path "Source")) {
		New-Item "Source" -ItemType Directory | Out-Null
	}
	notepad.exe "Cruiser-Config.ps1"
	Write-Host "Cruiser working directory initialized." -ForegroundColor Green
}

function Load-Config {
	$config_path = (Expand-Path -Path ".\Cruiser-Config.ps1")
	if (-not (Test-Path $config_path)) {
		Log "LoadConfig" ("Config Not found - {0}" -f $config_path)
		return $false
	}

	Log "Load-Config" $config_path
	
	. $config_path
	
	$config.source_dir = (Expand-Path -Path $config.source_dir)
	$config.output_dir = (Expand-Path -Path $config.output_dir)
	$config.log_path = (Expand-Path -Path $config.log_path)
	$config.history_path = (Expand-Path -Path $config.history_path)
	
	$config.history_path = (Expand-Path -Path $config.history_path)
	$global.status_xslt_path = (Expand-Path -Path $global.status_xslt_path)
	
	Log "Load-Config" $config.log_path
	
	$config.GetEnumerator() | sort -Property Key | foreach { Log "Config" $_.Value -Key $_.Key }	
	
	Load-History
	return $true
}

function Setup-Build {
	$script:build = @{}
	
	Log-Separator
	Log-Separator

	Log "Setup-Build" "Begin" -IncludeTimeStamp
	Set-BuildState -Message "Setup"
	
	$project.state_path = ($config.project_state_path -f $project.name)
	$project.state_path = (Expand-Path -Path $project.state_path)
	Load-ProjectState
	
	if (-not $history.ContainsKey($project.name)) {
		$history[$project.name] = @{}
	}
	$script:project_history = $history[$project.name]
	
	if (-not $project_history.ContainsKey("builds")) {
		$project_history.builds = @()
	}
	
	if ($project.version_scheme -eq "semantic") {
		if ($project_state.ContainsKey("version_build")) {
			$build.version_build = $project_state.version_build + 1
		} else {
			$build.version_build = $project.initial_version_build
		}		
		$build.version = "{0}.{1}" -f $project.version_prefix, $build.version_build
	} else {
		$build.version = (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
	}
	
	$build.id = ("{0}_{1}" -f $project.name, $build.version)
	$build.source_dir = ("{0}\{1}" -f $config.source_dir, $project.name)
	$build.output_dir = ("{0}\{1}\{2}" -f $config.output_dir, $project.name, $build.id)
	$build.start = (Get-Date)
	$build.start_str = ("{0:yyyy-MM-dd h:mm tt}" -f $build.start)

	$build.source_dir = (Expand-Path -Path $build.source_dir)
	$build.output_dir = (Expand-Path -Path $build.output_dir)
	
	$build.log_spool = @()
	if ($build.ContainsKey("log_path")) {
		$build.Remove("log_path")
	}

	$project.GetEnumerator() | sort -Property Key | foreach { Log "Project" $_.Value -Key $_.Key }
	#$build.GetEnumerator() | sort -Property Key | foreach { Log "Build" $_.Value -Key $_.Key }
	
	Log "Setup-Build" "End" -IncludeTimeStamp

}


function Check-Source {
	Log "Check-Source" "Begin" -IncludeTimeStamp

	if ($project.force_build -eq $true) {
		Log "Check-Source" "Forced build."
		$build.enable = $true
		return
	}

	$branch = "default"
	if ($project.ContainsKey("repo_branch")) {
		$branch = $project.repo_branch
	}

	if ($project.repo_type -eq "hg") {

		if (-not $project_state.ContainsKey("last_modified")) {
			$project_state.last_modified = ""
		}
		$exec = "{0} id -r {1} `"{2}`"" -f $config.hg_path, $branch, $project.repo_address
		$build.last_modified = (Exec $exec "Check-Source")
		$build.enable = ($project_state.last_modified -ne $build.last_modified)			

	} elseif ($project.repo_type -eq "git") {

		$build.enable = $true

	} elseif ($project.repo_type -eq "filesystem") {

		if (-not $project_state.ContainsKey("last_modified")) {
			$project_state.last_modified = [DateTime]::MinValue
		}

		$build.last_modified = (Get-ChildItem ("{0}\*" -f $project.repo_address) -Recurse `
									| Sort-Object LastWriteTime -Descending `
									| Select-Object -First 1).LastWriteTime
		Log "Check-Source" $project_state.last_modified -Key "LastWriteTime"
		$build.enable = ($project_state.last_modified -lt $build.last_modified)

	}
	
	$project_state.last_modified = $build.last_modified
	
	if ($build.enable -ne $true) {
		Log "Check-Source" "No changes detected."
	}

	Log "Check-Source" "End" -IncludeTimeStamp
}

function Get-Source {
	Log "Get-Source" "Begin" -IncludeTimeStamp
	Set-BuildState -Message "GetSource"
	
	$project_history.builds += $build


	Ensure-Directory $build.source_dir
	
	if ($project.repo_type -eq "hg") {
		
		$branch = "default"
		if ($project.ContainsKey("repo_branch")) {
			$branch = $project.repo_branch
		}

		$exec = "{0} clone -b {1} `"{2}`" `"{3}`"" -f $config.hg_path, $branch, $project.repo_address, $build.source_dir
		Exec $exec  "Get-Source" | Out-Null
		
	} elseif ($project.repo_type -eq "git") {
	
		$branch = "master"
		if ($project.ContainsKey("repo_branch")) {
			$branch = $project.repo_branch
		}

		$exec = "{0} clone -b {1} `"{2}`" `"{3}`"" -f $config.git_path, $branch, $project.repo_address, $build.source_dir
		Exec $exec  "Get-Source" | Out-Null
	
	} elseif ($project.repo_type -eq "filesystem") {
	
		Copy-Directory -Source $project.repo_address -Destination $build.source_dir -Exclude @("*\obj*", "*\bin*", "*.vspscc")
		
	}
	Log "Get-Source" "End" -IncludeTimeStamp
}

function Build {
	Log "Build" "Begin" -IncludeTimeStamp
	Set-BuildState -Message "Build"
	
	Ensure-Directory $build.output_dir
	$build.log_path = "{0}\{1}.log" -f $build.output_dir, $build.id

	$scripts = Get-ChildItem -Include "build.ps1" -Recurse -Path $build.source_dir
	if ($scripts -ne $null) {
		foreach ($script in $scripts) {
			Log "Build" $script
			$global.build_script = $script
			$script | Invoke-Expression
		}
	} else {
		Log "Build" "No build scripts found"
	}
	Log "Build" "End" -IncludeTimeStamp
}

function Cleanup {
	Log "Cleanup" "Begin" -IncludeTimeStamp
	Set-BuildState -Message "Cleanup"
	Remove-Directory $build.source_dir
	Log "Cleanup" "End" -IncludeTimeStamp
}

function Finish {
	Log "Finish" "Begin" -IncludeTimeStamp
	Set-BuildState -Message "Finish"
	
	$build.end = (Get-Date)
	$build.end_str = ("{0:yyyy-MM-dd h:mm tt}" -f $build.end)
	
	$project_state.version_build = $build.version_build
	
	Save-ProjectState
	Save-History

	Set-BuildState -Message "Done" -IncludeTimeStamp
	Log -category "System" -message ("{0} Done." -f $project.name) -IncludeTimeStamp

	$build.log_spool = @()
}

function Load-History {
	$script:history = @{}
	if (Test-Path $config.history_path) {
		Log "Load-History" $config.history_path
		$script:history = (Import-Clixml -Path $config.history_path)
	} else {
		Log "Load-History" ("Not found -- {0}" -f $config.history_path)
	}
}

function Load-ProjectState {
	$script:project_state = @{}
	if (Test-Path $project.state_path) {
		Log "Load-ProjectState" $project.state_path
		$script:project_state = (Import-Clixml -Path $project.state_path)
	} else {
		Log "Load-ProjectState" ("Not found -- {0}" -f $project.state_path)
	}
}

function Set-BuildState {
	param([string]$Message)

	Log "Set-BuildState" $Message
	$build.state = $Message
	Save-History
}

function Save-ProjectState {
	Log "Save-ProjectState" $project.state_path
	$project_state | Export-Clixml -Path $project.state_path -Depth 10
}

function Save-History {
	Log "Save-History" $config.history_path

	if ($project_list) {
		foreach ($p in $project_list) {
			$h = $history[$p.name]
			if ($h -and $h.ContainsKey("builds")) {
				if ($h.builds.count -gt $config.build_history_limit) {
					$h.builds = $h.builds | Select-Object -Last $config.build_history_limit
				}
			}
		}
	}	
	
	$history | Export-Clixml -Path $config.history_path -Depth 10
	
	Get-Item $config.history_path `
		| Convert-Xml -XsltPath $global.status_xslt_path `
		| Out-File -FilePath $config.html_status_path -Encoding ascii
}


function Wait {
	$history.next_poll_start = (Get-Date).AddMinutes($config.poll_interval)
	$history.next_poll_start_str = ("{0:yyyy-MM-dd h:mm tt}" -f $history.next_poll_start)
	Save-History
	Log -Category "Wait" -Message ("{0} minutes ({1})" -f $config.poll_interval, $history.next_poll_start_str) -IncludeTimeStamp
	Start-Sleep -Seconds ($config.poll_interval * 60)
}


########################################
# Core Project helper functions
########################################

function Build-FileProject {
	param([string]$RelativePath)
	
	$sdir = $global.build_script.Directory;
	$odir = $build.output_dir
	if ($RelativePath) {
		$odir = "{0}\{1}" -f $odir, $RelativePath
	}
	
	Log "BuildWebProject" $sdir -Key "Source"
	Log "BuildWebProject" $odir -Key "Destination"
	Ensure-Directory $odir
	Copy-Directory $sdir $odir -Exclude "build.ps1"
}

function Build-WebProject {
	param([string]$RelativePath)
	
	Build-FileProject -RelativePath $RelativePath
}

function Build-ClassConsole {
	param([string]$RelativePath)
	
	Build-ClassLibrary -RelativePath $RelativePath
}

function Build-ClassLibrary {
	param([string]$RelativePath)
	
	$sdir = $global.build_script.Directory;
	$odir = $build.output_dir
	if ($RelativePath) {
		$odir = "{0}\{1}" -f $odir, $RelativePath
	}
	
	Log "BuildClassLibrary" $sdir -Key "Source"
	Log "BuildClassLibrary" $odir -Key "Destination"
	Ensure-Directory $odir
	
	$ps = Get-ChildItem "$sdir\*" -Include "*.csproj"
	
	if ($ps) {
		foreach ($p in $ps) {
			$msbuild = "{0} `"{2}`" /t:ReBuild /p:Configuration={1} " -f $config.msbuild_path, $project.build_configuration, $p
			$msbuild_output = (Exec $msbuild "MSBuild")
		}
	}
	
	Copy-Item ("{0}\bin\{1}\*" -f $sdir, $project.build_configuration) -Destination $odir -PassThru `
		| ForEach-Object { Log "Copy-File" $_.ToString() }
}


########################################
# Utilities
########################################

function Log {
	param([string]$Category, [string]$Message, [switch]$IncludeTimeStamp, [string]$Key)
	
	$mask = "[ {0,20}{1} ] {2}{3}"
	$ts = ""
	if ($IncludeTimeStamp) {
		$ts = (" | {0:yyyy-MM-dd HH:mm:ss}" -f (Get-Date))
	}
	if ($Key) {
		$ks = ("{0,23}: " -f $Key)
	}

	$log_out = $mask -f $Category, $ts, $ks, $Message
	
	if ($build) {
		if ($build.ContainsKey("log_path")) {
			if ($build.ContainsKey("log_spool")) {
				Add-Content $build.log_spool -Path $build.log_path -Encoding Ascii
				$build.Remove("log_spool")
			}
			Add-Content $log_out -Path $build.log_path -Encoding Ascii
		} else {
			$build.log_spool += $log_out
		}
	}
	
	if ($config.log_path) {
		Add-Content $log_out -Path $config.log_path -Encoding Ascii
	}

	Write-Host $log_out
}

function Log-Key {
	param([string]$Category, [string]$Key, [string]$Message)
	
	Log $Category ("{0,23}: {1}" -f $Key, $Message)
}


function Log-Separator() {
	Log "" "==========================================================================="
}


function Exec {
        param([string]$Command, [string]$LogCategory)
        
        if (-not $LogCategory) {
                $LogCategory = "Exec"
        }
        Log $LogCategory $Command
        Invoke-Expression -Command $Command 2>&1 | foreach { Log $LogCategory $_ }
        #return $ret
}


function Expand-Path {
	param([string]$Path)
	
	if (Test-Path $Path) {
		return (Get-Item -Path $Path).FullName
	} else {
		return $Path
	}
}

function Copy-Directory {
	param([string]$Source, [string]$Destination, [array]$Exclude)
	
	$items = Get-Childitem $Source -Recurse
	
	Log-Key "Copy-Directory" "Source" $Source
	Log-Key "Copy-Directory" "Destination" $Destination
	
	Ensure-Directory -Path $Destination
	
    foreach ($item in $items) {
		$inc = $true
		foreach ($m in $Exclude) {
			if ($item.FullName -like $m) {
				$inc = $false
				break
			}			
		}
		
		if ($inc) {
	        $target = Join-Path $Destination $item.FullName.Substring($Source.Length)
	        if (-not ($item.PSIsContainer -and (Test-Path $target))) {
	            Copy-Item -Path $item.FullName -Destination $target
				Log "Copy-File" $target
	        }
		}
    }
}

function Ensure-Directory {
	param([string]$Path)
	
	if (-not (Test-Path $Path)) {
		Log "CreateDirectory" $Path
		New-Item -Type directory -Path $Path | Out-Null
	}
}

function Remove-Directory {
	param([string]$Path)
	
	if (Test-Path $Path) {
		Log "Remove-Directory" $Path
		Remove-Item -Recurse -Path $Path -Force | Out-Null
	}
}

#cls
#cd "\source\buildserver"
#Start-Cruiser -Background -Server
#Start-Cruiser -Background
