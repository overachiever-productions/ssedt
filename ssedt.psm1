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
		Write-StepHeader -StepText "STEP 1 of 4: Specify Target SQL Server Instance:";
		
		$instances = @(Get-ExistingSqlServerInstanceNames);
		switch ($instances.Count) {
			0 {
				Write-Host "`n";
				Write-Host "`n";
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
				Write-Host "`n";
				
				[int]$choice = Request-Value -Message "`tPlease Specify the # for which SQL Server Instance to Target ";
				$SQL_INSTANCE = $options[$choice];
				
				if ([string]::IsNullOrWhiteSpace($SQL_INSTANCE)) {
					Write-Host "`n";
					Write-Host "`n";
					
					throw "Invalid Instance Specified. Please Specify the number to the LEFT of the Instance-Name to proceed.`n`n";
					exit;
				}
				
				Write-Host "`t> Using [$SQL_INSTANCE] as Target.";
			}
		}
		
		Write-StepHeader -StepText "STEP 2 of 4: Confirm Target Disks:";
		$currentTempdbDiskVolumes = Get-SqlVolumesByInstance -InstanceName $SQL_INSTANCE;
		
		Write-Host "`tCurrent Volumes Used by [tempdb] on $($SQL_INSTANCE): `n";
		
		[string]$serializedString = "";
		foreach ($volume in $currentTempdbDiskVolumes) {
			Write-Host "`t`t`t$($volume)";
			$serializedString += "$($volume),";
		}
		
		$serializedString = $serializedString.Substring(0, $serializedString.Length - 1);
		
		Write-Host "`n";
#		Write-Host "`tOPTIONS:"
#		Write-Host "`t`tPress ENTER to accept currently configured disks: [$serializedString]";
#		Write-Host "`t`tYou may ALSO explicitly specify a comma-delimited string of disks to use.";
#		Write-Host "`t`t`tWARNING: If you use any option OTHER than what is currently configured, you will need to..."
#		Write-Host "`t`t`t... modify the [tempdb] on [$SQL_INSTANCE] to ONLY use the disks specified.";
		
		[string]$disks = Read-Host;
		
		if ([string]::IsNullOrWhiteSpace($disks)){
			$disks = $serializedString;
		}
		
		
# !!!! TODO: https://overachieverllc.atlassian.net/browse/SSEDT-11		
		Write-StepHeader -StepText "STEP 3 of 4: Specify TempDb Directory Name (per volume):";
		
		$dirName = Request-ValueWithDefault -Message "Specify a value for tempdb dir: " -Default "SqlTempDbData";
		
		# 	4) DISK types? 
		# 		i.e., if we can detect that this is an EC2 instance, do we ask for NVMe vs EBS? 
		# 			what about on other platforms? 
		
		
		Write-StepHeader -StepText "STEP 4 of 4: Confirmation:";
		
		Write-Host "`tSpecified Configuration Options:";
		Write-Host "`t`tTarget SQL Server Instance: [$SQL_INSTANCE]";
		Write-Host "`t`tTarget Volumes to Provision During Startup: [$disks]";
		Write-Host "`t`tDirectoryName for [tempdb] data files (per disk): [$dirName]";
		
		Write-Host "`tPress CTRL+C to exit. ";
		Write-Host "`tPress ENTER to continue - with values specified above. "
		
		# TEMP write-out
		Clear-Host;
		
		Write-Host "PARAMETERS TO PASS IN TO JOB-CREATION/ENABLING-THINGY:"
		Write-Host "`tINSTANCE: [$SQL_INSTANCE]";
		Write-Host "`tVOLUMES:  [$disks]";
		Write-Host "`tDIRNAMES: [$dirName]";
		
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
		
		$results = Invoke-Expression $command;
		
		[int]$lineNumber = 0;
		[string[]]$output = @();
		foreach ($disk in ($results -split "`n")) {
			if ($lineNumber -ge 2) {
				$output += $disk;
			}
			
			$lineNumber++;
		}
		
		return $output;
	}
	catch {
		throw;
	}
}

filter Write-StepHeader {
	param (
		[string]$StepText
	);
	
	Clear-Host;
	Write-Host "--------------------------------------------------------------------------------";
	Write-Host "  ENABLING SSEDT Auto-Start for Ephemeral Disks Configuration";
	Write-Host "--------------------------------------------------------------------------------";
	Write-Host "";
	Write-Host "-- $StepText";
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