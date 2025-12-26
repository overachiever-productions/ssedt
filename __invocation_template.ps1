Set-StrictMode -Version 3.0;
#Requires -RunAsAdministrator; 

Import-Module -Name ssedt;

Set-EphemeralDisks -Volumes @("T", 'V');