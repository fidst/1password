#
# ===================================================================
# Purpose:           Reviews and actions all suspended users in 1password
# Author:            Isaac FIDST
# Date:              April 8, 2021
# Notes:             1. Must use Powershell
#                    2. Powershell for MAC: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-macos?view=powershell-7.1
#                    3. To run a PS script on mac: pwsh -File [filename]
#                    4. Uses: https://1password.com/downloads/command-line/
#                    5. You MUST log into 1password via command PRIOR to running this script
# Revision:          April 23, 2021
# ===================================================================
#

clear

# Adds a blank line at the end for easier reading
Function next_line(){write-host "`n"}
# Pauses for 2 seconds as if importing, giving the user a chance to read above
Function sleepy(){Start-Sleep -s 2}
#name of the script
$scriptTitle="1p_sus_del"
# Get the date
$dateStamp = get-date -uformat "%Y-%m-%d@%H-%M-%S"
# 0= not test
$runTest = 1


# function called later to check if user is in 1pass
function checkUser ($t) {
  # Gets a fresh list of the users in 1p
  $lUsers = op list users | ConvertFrom-Json
  # Checks in the fresh user list if the username is in it

  $clUsers = $lUsers | Where-Object {$_.email -eq $t}
  # Returns t/f
  if ($clUsers -eq $null) {
    # If not in 1Pass return False
    return "FALSE"
  } else {
    # If in 1Pass return True
    return "TRUE"
  }
}

# Functions to find txt file of people to skip
# import ignore txt file. This is a seperate function to allow a file check later on
Function getTXT()
{
# check if files exist
$fileToCheckTEST    = ".\test.txt"
$fileToCheckNOTTEST = ".\ignore.txt"
  # Checks if this is a test
  If ($runTest -eq 1)
  {
    if (Test-Path $fileToCheckTEST -PathType leaf)
    {
    $Global:1pfile = ".\test.txt"}else{
      write-host "Creating ignore files. Restart script."
      New-Item -Name $fileToCheckTEST  -ItemType File
      exit
    }
      } else {
        if (Test-Path $fileToCheckNOTTEST -PathType leaf)
        {
    $Global:1pfile = ".\ignore.txt"}else{
      write-host "Creating ignore files. Restart script."
  New-Item -Name $fileToCheckNOTTEST -ItemType File
  exit
    }
  }
}


function processText(){
# get the ignore file
  getTXT
  # Import the ignore file as an array
    [string[]]$Global:ignoreArray = Get-Content -Path $1pfile
  # Sets the process for ignoring to true
    $Global:ignoreUsers="TRUE"
  # Displays the ignored users and pauses for dramatic effect
  If (@($ignoreArray).Count -ne 0)
  {
    next_line
    write-host "Ignoring these users:"
    $ignoreArray
    sleepy
    next_line
  }
}


function createLOG(){
# log all names to document
# create blank logging csv
    # Name of the log csv (based on the title and date variables)
    $1pImportOutput = "$scriptTitle-$dateStamp-temp.csv"
    # Location of the log csv
    $Global:1pImportFile = "$1pImportOutput"
    # Tells the user that the log csv is being made
    write-host "Creating new log CSV: $1pImportFile"
    # The headers in the log csv (MUST match the array made later on)
    Set-Content $1pImportFile -Value "Email,State,NeedRemoval,Ignored,ConfirmRemoval"

    # Sets and creates the final log after confirming the user is or is not in 1pass
    # Name of the log csv (based on the title and date variables)
    $1pImportFileFinal = "$scriptTitle-$dateStamp-final.csv"
    # Location of the log csv
    $Global:1pImportOutputFinal = "$1pImportFileFinal"
    Set-Content $1pImportOutputFinal -Value "Email,State,NeedRemoval,Ignored,ConfirmRemoval"

    next_line
}

function processUsers(){


# Loops through each property in the user object (each user reported) and sorts it into 2 arrays
# get list of all users (converts the json to an object for easy manipulation)
$1pusers = op list users | Convertfrom-json
# Count of users:
$1pcount = $1pusers.count
# Sets count to 1 for the loop later on
$n=1
# Declares empty suspended user array
$susUsers = @()
# Declares empty not suspended user array
$nSusUsers = @()
# Creates a log array to be later injected into a csv (must match headers in the csv creation)
$logFileO=New-Object PSObject -Property @{
Email=""
State=""
NeedRemoval=""
Ignored=""
ConfirmRemoval=""
}

write-host "Sorting Users"
foreach ($user in $1pusers)
{
  # Creates the initial log output made from the email and state from the object
  $useremail = $user.email
  $userstate = $user.state

# if user is suspended add to array
# If the user has a state of "S", they are suspended

  If ($userstate -eq "S")
  {
    # if suspended, add to suspended user array
$susUsers += $useremail
  } else {
    # if not suspended, add to not suspended user array
$nSusUsers += $useremail
  }
} #End for loop

write-host "Actioning Suspended Users"
  foreach ($email in $susUsers)
  {
# Action the suspeded users
$logFileO.State = "S"
$logFileO.Email = $useremail = $email
# If the state is suspended, they need removal, lets log that
$logFileO.NeedRemoval = "TRUE"


If ($ignoreUsers="TRUE")
{
  If (@($ignoreArray).Count -ne 0)
  {
  # if in array, ignore
  If ($ignoreArray.Contains($useremail))
  {
  $logFileO.Ignored="TRUE"
  write-host "Ignoring the user: $useremail"
  }else{
    $logFileO.Ignored="FALSE"
    If ($runTest -eq 1){write-host "THIS IS A TEST -  (Deletion process) $useremail"}
    else {op delete user $useremail}
  }
}else{
  $logFileO.Ignored="FALSE"
  If ($runTest -eq 1){write-host "THIS IS A TEST -  (Deletion process) $useremail"}
  else {op delete user $useremail}
}
}

# Outputs the log array to the csv
  $logFileO | Export-CSV $1pImportFile -Append -NoTypeInformation -Force

  }# end forloop

  foreach ($email in $nSusUsers)
  {
# Action the suspeded users
$logFileO.State = "A"
$logFileO.Email = $useremail = $email
$logFileO.NeedRemoval = "FALSE"
$logFileO.Ignored     = "TRUE"

# Outputs the log array to the csv
  $logFileO | Export-CSV $1pImportFile -Append -NoTypeInformation -Force

  }# end forloop

} # End function

function confirmRemoval () {

  # import csv
$1pImportFileFinal = Import-Csv .\$1pImportFile

  # create new csv
# $Global:1pImportOutputFinal = "$scriptTitle-$dateStamp-final.csv"
# Set-Content $1pImportOutputFinal -Value "Email,State,NeedRemoval,Ignored,ConfirmRemoval"

  # create new object from 1password
$1pusers = op list users | Convertfrom-json
# Adding each email to an array
$userEmails = @()
Foreach ($user in $1pusers)
{
$userEmails += $user.email
}

write-host "Confirming removal of users"
write-host "Logging to $1pImportOutputFinal"

  # for each user in old csv, check if in 1pass object
  foreach ($user in $1pImportFileFinal)
  {
    if (![string]::IsNullOrEmpty($user.Email) -Or ![string]::IsNullOrEmpty($user.State))
  {
    # Creates a log array to be later injected into a csv (must match headers in the csv creation)
    $logFile1=New-Object PSObject -Property @{
    Email=""
    State=""
    NeedRemoval=""
    Ignored=""
    ConfirmRemoval=""
    }

$logFile1.Email       = $uEmail          = $user.email
$logFile1.State       = $uState          = $user.state
$logFile1.NeedRemoval = $uNeedRemoval    = $user.NeedRemoval
$logFile1.Ignored     = $uIgnored        = $user.Ignored

  If ($userEmails.Contains($uEmail))
  {
    $logFile1.ConfirmRemoval = "FALSE"
  }else{
    $logFile1.ConfirmRemoval = "TRUE"
  }

  # output to new csv
  # Outputs all information for the user (based on the log array)
  # Outputs the log array to the csv
  $logFile1 | Export-CSV $1pImportOutputFinal -Append -NoTypeInformation -Force
}

}

  # delete old csv
  write-host "Removing original import CSV"
  Remove-Item -Path .\$1pImportFile -Force
}



# --------

getTXT

if (Test-Path $1pfile -PathType leaf)
{
  If ($runTest -eq 1)
  {
write-host "THIS IS A TEST - Using test.txt."
processText
createLOG
processUsers
confirmRemoval
}else{
  Write-Warning "This is not a test, do you wish to run?"
  $askRun = Read-Host -Prompt '(y/n) '
  if($askRun -eq "y")
  {
    write-host "THIS IS NOT A TEST - Using ignore.txt"
    processText
    createLOG
    processUsers
    confirmRemoval
  }else{
    Write-host "Ending."
  }
}
}else{
  next_line
  write-host "No ignore txt file, not actioning deletions."
  write-host "Create a TXT file in the same directory as the script"
  write-host "If a test, use test.txt. If prod, use ignore.txt"
  next_line
}
