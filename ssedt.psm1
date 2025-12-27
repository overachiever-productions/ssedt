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
		
		# get user inputs for: 
		# 	1)	SQL Server Instance Name
		# 			ONLY bother ASKING for a name IF > 1 instance detected. Otherwise, just let users know what instance we're targeting
		
		# 	2)	TempDbVolumes (provide list of available/optional disks)
		
		#   3)	TempDb Dir Name
		# 			default the value to "sqltemp" or "SQLTempData"
		
		# 	4) DISK types? 
		# 		i.e., if we can detect that this is an EC2 instance, do we ask for NVMe vs EBS? 
		# 			what about on other platforms? 
		
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
			
			# TODO: make sure we can match the $Instance passed in ... i.e., throw if that's incorrect. 
			
			Write-Host "Pretending to Setup Ephemeral Disks (with the following inputs): ";
			Write-Host "`tInstance: [$Instance]";
			Write-Host "`tVolumes: [$Volumes]";
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
		[string]$TaskName = "Provision Ephemeral Disks at Startup",
		[Parameter(Mandatory)]
		[string]$Command
	);
	
	# TODO: verbose logging for ... troubleshooting etc. 
	# 		including ... PRINTING the $Command FIRST. (before it's base-64 encoded)
	# 			and then printing it AFTER ... along with all details/etc. 
	
	# TODO: 
	# 		might also want to CHECK to see if the scheduled task was created? 
	
	try {
		$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue;
		if ($null -ne $task) {
			Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null;
		}
		
		$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay 00:00:04;
		$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew;
		
		$executatablePath = Join-Path -Path $PSHOME -ChildPath "powershell.exe";
		$taskArguments = "-ExecutionPolicy BYPASS -NoProfile -EncodedCommand $EncodedCommand ";
		$action = New-ScheduledTaskAction -Execute $executatablePath -Argument $taskArguments;
		
		$description = "Script / Task to Auto-Provision Ephemeral disks, directories, and perms.";
		Register-ScheduledTask -TaskName $TaskName -Trigger $trigger -Action $action -Settings $settings -User "SYSTEM" -RunLevel Highest -Description $description | Out-Null;
	}
	catch {
		throw "Ruh roh. failed to create task.";
	}
}

# ==================================================================================================================================
# EXPORT:
# ==================================================================================================================================	
Export-ModuleMember -Function Enable-AutoStartForEphemeralDisks, Set-EphemeralDisks;