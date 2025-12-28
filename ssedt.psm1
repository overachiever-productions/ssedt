# ==================================================================================================================================
# PUBLIC:
# ==================================================================================================================================	
function Confirm-EphemeralDisksAutoStartDetails {
	[CmdletBinding()]
	param (
		
	);
	
	begin {
		
		# TODO: https://overachieverllc.atlassian.net/browse/SSEDT-13
		
		# TODO:
		# 		Need to confirm the following: 
		# 		- User has elevation enough to create a job that will run as SYSTEM. 
		# 		- SSEDT module is installed to a location where ... SYSTEM can get to it.
		# 		AND... the FACADE needs to check this stuff - to help end-users (and not let them get going far enough to then throw an error)
		# 		AND ... the non-facade ALSO needs to check this stuff as well. 
	};
	
	process {
		Clear-Host;
		Write-Host "--------------------------------------------------------------------------------";
		Write-Host "  ENABLING SSEDT Auto-Start for Ephemeral Disks Configuration";
		Write-Host "--------------------------------------------------------------------------------";
		Write-StepHeader -StepText "STEP 1 of 4: Specify Target SQL Server Instance:";
		
		$instances = @(Get-ExistingSqlServerInstanceNames);
		switch ($instances.Count) {
			0 {
				throw "SQL Server is NOT installed. Can NOT proceed with auto-provisioning setup.";
				exit;
			}
			1 {
				$SQL_INSTANCE = $instances[0];
				Write-Host "`t> SINGLE SQL SERVER INSTANCE Detected: $SQL_INSTANCE. Using [$SQL_INSTANCE] as Target.";
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
				
				[int]$choice = Request-Value -Message "`tPlease Specify the # for which SQL Server Instance to Target ";
				$SQL_INSTANCE = $options[$choice];
				
				if ([string]::IsNullOrWhiteSpace($SQL_INSTANCE)) {
					throw "Invalid Instance Specified. Please Specify the number to the LEFT of the Instance-Name to proceed.`n`n";
					return;
				}
				
				Write-Host "`t> Using [$SQL_INSTANCE] as Target.";
			}
		}
		
		Write-StepHeader -StepText "STEP 2 of 4: Confirm Target Volumes:";
		$currentTempdbDiskVolumes = Get-SqlVolumesByInstance -InstanceName $SQL_INSTANCE;
		[string]$SERIALIZED_DISKS = $currentTempdbDiskVolumes -join ",";
		Write-Host "`t> Volumes in use by [tempdb] on Instance [$SQL_INSTANCE] are: [$SERIALIZED_DISKS]";
		
		Write-StepHeader -StepText "STEP 3 of 4: Specify TempDb Directory Name (per volume):";
		$directories = @(Get-TempdbDirectoryNames);
		switch ($directories.Count) {
			0 {
				throw "Could not extract directory from [master].[sys].[master_files] for [tempdb] on SQL Instance: [$SQL_INSTANCE]. Terminating.";
				return;
			}
			1 {
				[string]$DIR_NAME = $directories[0];
				Write-Host "`t > Directory-Name for [tempdb] files on [$SQL_INSTANCE] is: [$DIR_NAME].";
			}
			default {
				throw "Configuration problem with [tempdb] on SQL Server Instance [$SQL_INSTANCE]: there are MULTIPLE directories against different volumes specified for the path to [tempdb] files.";
				Write-Host "`t`tQuery [master].[sys].[master_files] WHERE [database_id] = 2 for directory/path names. (ssedt requires a standardized (single) directory-name across all volumes.)";
				return;
			}
		}
		
		# 	4) DISK types? 
		# 		i.e., if we can detect that this is an EC2 instance, do we ask for NVMe vs EBS? 
		# 			what about on other platforms? 
		
		Write-StepHeader -StepText "STEP 4 of 4: Confirmation:";
		Write-Host "`t> Current SQL Server [tempdb] Configuration Settings:";
		Write-Host "`t`t-> SQL Server Instance: [$SQL_INSTANCE]";
		Write-Host "`t`t-> Volumes to Provision at Startup: [$SERIALIZED_DISKS]";
		Write-Host "`t`t-> DirectoryName for [tempdb] data files: [$DIR_NAME]";
		
		Write-Host "`n`t!!Please Verify the above settings.!!";
		Write-Host "";
		[string]$choice = Request-Value -Message "`To Proceed type 'yes'. (To abort, press enter or any other key.)";
		
		if ("yes" -ne $choice) {
			Write-Host "`t> Supplied Input: [$choice].";
			Write-Host "`t> Terminating...";
			return;
		}
		
		Register-EphemeralDisksAutoStartJob -Instance $SQL_INSTANCE -Volumes $directories -DirectoryName $DIR_NAME;
	};
	
	end {
		
	};
}

function Register-EphemeralDisksAutoStartJob {
	param (
		[Alias('SqlInstanceName', 'InstanceName')]
		[string]$Instance = "MSSQLSERVER",
		
		[Alias('TempDbVolumes')]
		[Parameter(Mandatory)]
		[string[]]$Volumes,

		[Alias('TempDbDirectoryNameDirectoryName')]
		[string]$DirectoryName = "sqltemp"
	);
	
	begin {
		
		# TODO:
		# 		Need to confirm the following: 
		# 		- User has elevation enough to create a job that will run as SYSTEM. 
		# 		- SSEDT module is installed to a location where ... SYSTEM can get to it.
		# 		AND... the FACADE needs to check this stuff - to help end-users (and not let them get going far enough to then throw an error)
		# 		AND ... the non-facade ALSO needs to check this stuff as well. 			
	};
	
	process {
		
		[string]$serializedVolumes = ($Volumes | ForEach-Object { "'$_'" }) -join ",";
		
		[string]$command = @"
Import-Module -Name ssedt;
Set-EphemeralDisksForSqlServer -Volumes @() -Instance "MSSQLSERVER" -DirectoryName "sqltemp";
"@;
		
		$command = $command.Replace("MSSQLSERVER", $Instance);
		$command = $command.Replace("@()", "@($serializedVolumes)");
		$command = $command.Replace("sqltemp", "$DirectoryName");
		
		New-JobForEphemeralDisksAutoStart -Command $command;
	};
	
	end {
		
	};
}

function Set-EphemeralDisksForSqlServer {
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
		
		# TODO
		# !!!!		https://overachieverllc.atlassian.net/browse/SSEDT-10
		
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

function UnRegister-EphemeralDisksAutoStartJob {
	throw "Not Yet Implemented.";
	# https://overachieverllc.atlassian.net/browse/SSEDT-15
	
	# TODO: hmmm. This'll need an instance name (eventually).
}

# ==================================================================================================================================
# INTERNAL:
# ==================================================================================================================================	
filter New-JobForEphemeralDisksAutoStart {
	param (
		[string]$TaskName = "Provision Ephemeral Disks at Startup",
		[Parameter(Mandatory)]
		[string]$Command
	);
	
	Write-Verbose "COMMAND: [$Command]";
	
	$bytes = [System.Text.Encoding]::Unicode.GetBytes($Command);
	[string]$EncodedCommand = [Convert]::ToBase64String($bytes);
	
	Write-Verbose "COMMAND - BASE64: [$EncodedCommand]";
	
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
		# TODO:
		throw "Ruh roh. failed to create task.";
	}
	
	# TODO: report on outcome... 
}

filter Get-ExistingSqlServerInstanceNames {
	
	# TESTING HACK: 
	if ([System.Net.Dns]::GetHostName() -in ("WIN-EHJTPLI2M43", "WORKSTATION")) {
		return @("MSSQLSERVER");
	}
	
	[string[]]$output = @();
	
	$key = Get-Item 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server' -ErrorAction SilentlyContinue;
	if (($key -eq $null) -or ([string]::IsNullOrEmpty($key.Property))) {
		return $output;
	}
	
	[string[]]$output = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server').InstalledInstances;
	return $output;
}

filter Get-ConnectionInstance {
	param (
		[Parameter(Mandatory)]
		[string]$InstanceName
	);
	if ($InstanceName -ne "MSSQLSERVER") {
		return ".\$InstanceName";
	}
	
	return ".";
}

filter Get-SqlVolumesByInstance {
	param (
		$InstanceName
	);
	
	# TESTING HACK:
	if ([System.Net.Dns]::GetHostName() -in ("WIN-EHJTPLI2M43", "WORKSTATION")) {
		return @("T", "V");
	}
	
	try {
		$command = "& SQLCMD -S $(Get-ConnectionInstance -InstanceName $InstanceName) -Q `"SET NOCOUNT ON; SELECT DISTINCT(LEFT([physical_name], 1)) [volume] FROM master.sys.master_files WHERE database_id = 2; `";";
		
		$results = Get-SimpleSqlResults -Command;
		return $results;
	}
	catch {
		throw;
	}
}

filter Get-TempdbDirectoryNames {
	param (
		$InstanceName
	);
	
	# TESTING HACK:
	if ([System.Net.Dns]::GetHostName() -in ("WIN-EHJTPLI2M43", "WORKSTATION")) {
		return @("SQLData");
	}
	
	try {
		$command = "& SQLCMD -S $(Get-ConnectionInstance -InstanceName $InstanceName) -Q `"SELECT DISTINCT SUBSTRING([physical_name], 0, LEN([physical_name]) - CHARINDEX(N'\', REVERSE([physical_name])) + 1) [path] FROM sys.master_files WHERE [database_id] = 2; `";";
		
		$results = Get-SimpleSqlResults -Command;
		return $results;
	}
	catch {
		# TODO: 
		throw "ruh roh!";
	}
}

filter Get-SimpleSqlResults {
	param (
		[string]$Command
	);
	
	$results = Invoke-Expression $Command;
	
	[int]$lineNumber = 0;
	[string[]]$output = @();
	foreach ($disk in ($results -split "`n")) {
		if ($lineNumber -ge 2) {
			$output += $disk.Trim();
		}
		
		$lineNumber++;
	}
	
	return $output;
}

filter Write-StepHeader {
	param (
		[string]$StepText
	);
	
	Write-Host "";
	Write-Host "  $StepText";
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
Export-ModuleMember -Function Confirm-EphemeralDisksAutoStartDetails, Register-EphemeralDisksAutoStartJob, Set-EphemeralDisksForSqlServer, UnRegister-EphemeralDisksAutoStartJob;