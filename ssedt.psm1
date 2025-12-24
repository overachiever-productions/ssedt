# ==================================================================================================================================
# PUBLIC:
# ==================================================================================================================================	
function Enable-AutoStartForEphemeralDisks {
	[CmdletBinding()]
	# hmm... do I want to let the USER specify a location for the 'InvokeEphemeralDisksSetup.ps1' script? 
	# 		probably. i.e., default it to ... C:\PerfLogs? or maybe <path-to-sql-server-stuff>? 
	# 		but ... let users specify an entire path? 
	param (
		
	);
	
	begin {
		
	};
	
	process {
		param (
			[Parameter(Mandatory)]
			[string]$ScriptPath,
			[string]$TaskName = "Provision Ephemeral Disks at Startup"
		);
		
		$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue;
		if ($null -ne $task) {
			Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null;
		}
		
		$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:00:04;
		$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew;
		
		$taskArguments = "-ExecutionPolicy BYPASS -NoProfile -File `"$($ScriptPath)`" ";
		$executatablePath = Join-Path -Path $PSHOME -ChildPath "powershell.exe";  		# MKC: could do pwsh.exe IF PWSH 7/etc. installed. 
		$action = New-ScheduledTaskAction -Execute $executatablePath -Argument $taskArguments;
		
		$description = "Script / Task to Auto-Provision Ephemeral disks, directories, and perms.";
		Register-ScheduledTask -TaskName $TaskName -Trigger $trigger -Action $action -Settings $settings -User "SYSTEM" -RunLevel Highest -Description $description | Out-Null;
		
		# get user inputs... 
		
		# load `__invocation_template.ps1`
		# replace params/details as needed and persist as: 
		# 		<path>\InvokeEphemeralDisksSetup.ps1
		
		# destroy job if exists. 
		
		# create a job to execute <path>\InvokeEphemeralDisksSetup.ps1 upon startup
		# 		with all of the necessary switches. 
		# 		including -Verbose - i.e., any 'automated' call to Set-EphemeralDisks will always pass in -Verbose... 
		
	};
	
	end {
		
	};
}

# aliases might be Initialize-EphemeralDisks... and Mount-EphemeralDisks 
function Set-EphemeralDisks {
	[CmdletBinding()]
	param (
		[Alias('Volumes')]
		[Parameter(Mandatory)]
		[string[]]$TempDbVolumes,
		[Alias('Instance', 'InstanceName')]
		[string]$SqlInstanceName = "MSSQLSERVER",
		[string]$TempDbDirectoryName = "sqltemp"
	);
	
	begin {
		$transcriptFile = "C:\Windows\Temp\ssedt_transcript_$(Get-Date -Format "yyyy-MM-dd_hhmmss").txt";
		Start-Transcript -Path $transcriptFile;
		Write-Host "Transcript Started. Location: [$transcriptFile]";
	};
	
	process {
		Write-Host "Parameters: ";
		Write-Host "`tVolumes: [$TempDbVolumes]";
		Write-Host "`tInstance: [$SqlInstanceName]";
		Write-Host "`tTempDbDir: [$TempDbDirectoryName]";
	};
	
	end {
		
	};
}

# ==================================================================================================================================
# INTERNAL:
# ==================================================================================================================================	