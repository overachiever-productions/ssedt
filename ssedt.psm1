# ==================================================================================================================================
# PUBLIC:
# ==================================================================================================================================	
function Enable-AutoStartForEphemeralDisks {
	[CmdletBinding()]
	param (
		
	);
	
	begin {
		[string]$invocationTemplate = Get-InvocationTemplateContent;
	};
	
	process {
		
		# get user inputs... 
		
		# load templateData via `Get-InvocationTemplateContent`
		# replace params/details as needed and persist as: 
		# 		<path>\InvokeEphemeralDisksSetup.ps1
		
		# create a job to execute 
		# 		with all of the necessary switches. 
		# 		including -Verbose - i.e., any 'automated' call to Set-EphemeralDisks will always pass in -Verbose... 
		
	};
	
	end {
		
	};
}

function Set-EphemeralDisks {
	[CmdletBinding()]
	param (
		[Alias('TempDbVolumes')]
		[Parameter(Mandatory)]
		[string[]]$Volumes,
		[Alias('SqlInstanceName', 'InstanceName')]
		[string]$Instance = "MSSQLSERVER",
		[Alias('TempDbDirectoryNameDirectoryName')]
		[string]$DirectoryName = "sqltemp"
	);
	
	begin {
		$transcriptFile = "C:\Windows\Temp\ssedt_transcript_$(Get-Date -Format "yyyy-MM-dd_hhmmss").txt";
		Start-Transcript -Path $transcriptFile;
		Write-Host "Transcript Started. Location: [$transcriptFile]";
	};
	
	process {
		try {
			Write-Host "Parameters: ";
			Write-Host "`tVolumes: [$Volumes]";
			Write-Host "`tInstance: [$Instance]";
			Write-Host "`tTempDbDir: [$DirectoryName]";
		}
		catch {
			throw "ruh roh!";
		}
	};
	
	end {
		
	};
}

# ==================================================================================================================================
# INTERNAL:
# ==================================================================================================================================	
filter Get-InvocationTemplateContent {
	return @"
Set-StrictMode -Version 3.0;
#Requires -RunAsAdministrator; 
Import-Module -Name ssedt;

Set-EphemeralDisks -Volumes @() -Instance "MSSQLSERVER" -DirectoryName "sqltemp";
"@
}

filter New-JobForEphemeralDisksAutoStart {
	param (
		[Parameter(Mandatory)]
		[string]$TaskName = "Provision Ephemeral Disks at Startup"
		[Parameter(Mandatory)]
		[string]$Command
	);
	
	# TODO: try/catch. 
	# TODO: verbose logging for ... troubleshooting etc. 
	# 		including ... dropping out (i.e., printing) the $Command FIRST. (before it's base-64 encoded)
	
	$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue;
	if ($null -ne $task) {
		Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null;
	}
	
	$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:00:04;
	$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew;
	
	$taskArguments = "-ExecutionPolicy BYPASS -NoProfile -File `"$($ScriptPath)`" ";
#	$executatablePath = Join-Path -Path $PSHOME -ChildPath "powershell.exe"; 
	$action = New-ScheduledTaskAction -Execute $executatablePath -Argument $taskArguments;
	
	$description = "Script / Task to Auto-Provision Ephemeral disks, directories, and perms.";
	Register-ScheduledTask -TaskName $TaskName -Trigger $trigger -Action $action -Settings $settings -User "SYSTEM" -RunLevel Highest -Description $description | Out-Null;
}

# ==================================================================================================================================
# EXPORT:
# ==================================================================================================================================	
Export-ModuleMember -Function Enable-AutoStartForEphemeralDisks, Set-EphemeralDisks;