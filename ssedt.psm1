# ==================================================================================================================================
# PUBLIC:
# ==================================================================================================================================	
function Enable-AutoStartForEphemeralDisks {
	
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
		$transcriptFile = "C:\Windows\Temp\ssedt_transcript_$(Get-Date -Format "yyyy-mm-dd_hhMMss").txt";
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