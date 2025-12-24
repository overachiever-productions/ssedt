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