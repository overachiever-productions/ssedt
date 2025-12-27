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
		Clear-Host;
		
		Write-Host "--------------------------------------------------------------------------------";
		Write-Host "  STARTING SSEDT Auto-Start for Ephemeral Disks Configuration";
		Write-Host "--------------------------------------------------------------------------------";
		Write-Host "";
		Write-Host "--STEP 1 of 3: Specify Target SQL Server Instance:";
		
		$instances = @(Get-ExistingSqlServerInstanceNames);
		switch ($instances.Count) {
			0 {
				Write-Host "";
				Write-Host "";
				
				throw "SQL Server is NOT installed. Can NOT proceed with auto-provisioning setup.`n`n";
				exit;
			}
			1 {
				$SQL_INSTANCE = $instances[0];
				
				Write-Host "`t> SINGLE SQL SERVER INSTANCE Detected: $SQL_INSTANCE. Using [$SQL_INSTANCE] as Target.";
				s
			}
			default {
				Write-Host "`tMultiple SQL Server Instances Found: `n";
				[int]$key = 1;
				[hashtable]$options = @{};
				foreach ($instance in $instances) {
					Write-Host "`t`t`t$key - $instance";
					$options.Add($key, $instance);
					$key++;
				}
				Write-Host "";
				
				[int]$choice = Request-Value -Message "`tPlease Specify the # for which SQL Server Instance to Target ";
				$SQL_INSTANCE = $options[$choice];
				
				if ([string]::IsNullOrWhiteSpace($SQL_INSTANCE)) {
					throw "Invalid Instance Specified. Please Specify the number to the LEFT of the Instance-Name to proceed.";
					exit;
				}
			}
		}
		
		Write-Host "--STEP 2 of 3: Specify Target Disks:";
		
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

filter Get-ExistingSqlServerInstanceNames {
	
	# TESTING HACK: 
	if ("WIN-EHJTPLI2M43" -eq [System.Net.Dns]::GetHostName()) {
		return @("MSSQLSERVER");
	}
	
	if ("WORKSTATION" -eq [System.Net.Dns]::GetHostName()) {
		return @("MSSQLSERVER", "X3", "DEV");
	}
	
	[string[]]$output = @();
	
	$key = Get-Item 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server' -ErrorAction SilentlyContinue;
	if (($key -eq $null) -or ([string]::IsNullOrEmpty($key.Property))) {
		return $output;
	}
	
	[string[]]$output = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server').InstalledInstances;
	return $output;
}

filter Request-Value {
	param (
		[string]$Message
	);
	
	$output = Read-Host $Message;
	
	return $output;
}

filter Request-ValueWithDefault {
	param (
		[string]$Message,
		[string]$Default
	);
	
	if (-not ($output = Read-Host ($Message -f $Default))) {
		$output = $Default
	}
	
	return $output;
}


# ==================================================================================================================================
# EXPORT:
# ==================================================================================================================================	
Export-ModuleMember -Function Enable-AutoStartForEphemeralDisks, Set-EphemeralDisks;