$script:config = @{
	"history_path" = ".\Cruiser-History.xml";
	"build_history_limit" = 50;
	"project_state_path" = ".\{0}-State.xml";
	"log_path" = ".\Cruiser-{0:yyyy-MM-dd}.log" -f (Get-Date);
	"poll_interval" = 5; # minutes
	"source_dir" = ".\Source";
	"output_dir" = ".\Output";
	"html_status_path" = ".\Output\index.html";
	"hg_path" = "hg";
	"git_path" = "git";
	"tf_path" = "C:\Program Files (x86)\Microsoft Visual Studio 10.0\Common7\IDE\TF.exe";
	"msbuild_path" = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe";
}

$script:project_list = @( 
		@{
			"name" = "Cruiser";
			"enable" = $true;
			"repo_address" = "https://bitbucket.org/TechHike/cruiser";
			"repo_branch" = "default";
			"repo_type" = "hg";
			"version_scheme" = "semantic";
			"version_prefix" = "1.0";
			"initial_version_build" = 1;
			"force_build" = $false;
		}
);
