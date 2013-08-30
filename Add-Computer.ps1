<#
    .Synopsis
    Adds a computer into the All Desktop and Server Clients collection of SCCM 2012
    
    .Description
    addComputer takes a computer name and a MAC address and creates an object in the All Desktop and Server Clients collection of SCCM 2012.  There is a generic
    failure error when the object is create, even though the object appears in SCCM
    
    .Example
    addComputer snorlax 00:00:00:00:00:00
    Successful output will be "Computer added: snorlax 00:00:00:00:00:00"
#>

param (
    [Parameter(Mandatory=$True)][string]$ComputerName, 
    [Parameter(Mandatory=$True)][string]$MACAddress
)

$ServerName = "Itzamna"
$SiteCode = "KAT"
$CollectionName = "All Desktop and Server Clients"

#Grab the collection the machine is to be added to
$CollectionQuery = Get-WmiObject -ComputerName $ServerName -Namespace "Root\SMS\Site_$SiteCode" -Class SMS_Collection -Filter "Name='$CollectionName'"


#Create the connection and prep the object to be added
$WmiConnection = ([WMIClass]"\\$ServerName\root\SMS\Site_$($SiteCode):SMS_Site")
    $NewEntry = $WMIConnection.psbase.GetMethodParameters("ImportMachineEntry")
    $NewEntry.MACAddress = $MACAddress
    $NewEntry.NetbiosName = $ComputerName
    $NewEntry.OverwriteExistingRecord = $True
$Resource = $WmiConnection.psbase.InvokeMethod("ImportMachineEntry",$NewEntry,$null)

#Create the object to be added
$NewRule = ([WMIClass]"\\$ServerName\root\SMS\Site_$($SiteCode):SMS_CollectionRuleDirect").CreateInstance()
$NewRule.ResourceClassName = "SMS_R_SYSTEM"
$NewRule.ResourceID = $Resource.ResourceID
$NewRule.Rulename = $ComputerName

#AddMemberShipRule fails with a generic failure even though the computer is successfully added to SCCM
try 
{
    #Add computer to the collection in SCCM
    $CollectionQuery.AddMemberShipRule($NewRule)
}
catch 
{
    if ($_ -match "Generic failure") 
    {
        $ComputerExists = Get-WmiObject	-ComputerName $ServerName `
							-Query "SELECT ResourceID FROM SMS_R_System WHERE Name LIKE `'$ComputerName`'" `
							-Namespace "root\sms\site_$SiteCode"
        if ($ComputerExists -eq $null)
        {
            write-host -ForegroundColor Red "Computer not added"
        }
        else
        {
            write-host "Computer Added to" $CollectionName ": " -NoNewline
            write-host -ForegroundColor Green $ComputerName $MACAddress 
        }
    }
    else
    {
        $_
    }
}
