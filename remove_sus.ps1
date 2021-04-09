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
# Revision:          April 9, 2021
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
# get list of all users (converts the json to an object for easy manipulation)
$1pusers = op list users | Convertfrom-json
# Count of users:
$1pcount = $1pusers.count
# Sets count to 1 for the loop later on
$n=1
# 0= not test
$runTest = 1


# function called later to check if user is in 1pass
function checkUser ($t) {
  # Gets a fresh list of the users in 1p
  $lUsers = op list users | ConvertFrom-Json
  # Checks in the fresh user list if the username is in it
  $lUsers | Where-Object {$_.email -eq $t} | Out-Null
  # Returns t/f
  if ($lUsers -eq $null) {
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
  # Checks if this is a test
  If ($runTest -eq 1)
  {
    # This is a test, so let the user know and use test.txt
    write-host "THIS IS A TEST - Using test.txt."
    $Global:1pfile = ".\test.txt"
      } else {
    # This is NOT a test, so let the user know and use ignore.txt
    write-host "THIS IS NOT A TEST - Using ignore.txt"
    $Global:1pfile = ".\ignore.txt"
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
  If (@($ignoreArray).Count -eq 0)
  {
    $ignoreArray
    sleepy
  }
}


function createLOG(){
# log all names to document
# create blank logging csv
    # Name of the log csv (based on the title and date variables)
    $1pImportOutput = "$scriptTitle-$dateStamp.csv"
    # Location of the log csv
    $Global:1pImportFile = "$1pImportOutput"
    # Tells the user that the log csv is being made
    write-host "Creating new log CSV: $1pImportFile"
    # The headers in the log csv (MUST match the array made later on)
    Set-Content $1pImportFile -Value "Email,State,NeedRemoval,Ignored,ConfirmRemoval"
    sleepy
    next_line
}

function processUsers(){
# Loops through each property in the user object (each user reported)
foreach ($user in $1pusers)
{

# Show the progress
# Basic percentage math
$nP = [math]::Round(($n/$1pcount)*100,2)
# Shows the count and the math for each loop so you know how long you have to get coffee
write-host "$n/$1pcount ($nP%)"
next_line
# Adds 1 to the loop variable to let the math continue each loop
$n++

# if for what ever reason either the email or state of a user is empty, we skip it
  if (![string]::IsNullOrEmpty($user.state) -Or ![string]::IsNullOrEmpty($user.email))
{
  # Creates a log array to be later injected into a csv (must match headers in the csv creation)
  $logFileO=New-Object PSObject -Property @{
  Email=""
  State=""
  NeedRemoval=""
  Ignored=""
  ConfirmRemoval=""
  }

# Creates the initial log output made from the email and state from the object
  $logFileO.Email = $useremail = $user.email
  $logFileO.State = $userstate = $user.state

# If the user has a state of "S", they are suspended
  If ($userstate -eq "S")
  {
      # If the state is suspended, they need removal, lets log that
      $logFileO.NeedRemoval      = "TRUE"

      # DELETE USER
# If a test, output this is a test, and the email for visual representation
      If ($runTest -eq 1)
      {

          write-host "THIS IS A TEST -  (Deletion process) $useremail"
        If ($ignoreUsers="TRUE")
        {
          # if in array, ignore
          If (@($ignoreArray).Count -ne 0)
          {
          If ($ignoreArray.Contains($useremail))
          {
            $logFileO.Ignored="TRUET"
            write-host "THIS IS A TEST -  IGNORING $useremail"
          }else{
          $logFileO.Ignored="FALSE"
          write-host "THIS IS A TEST -  NOT IGNORING $useremail"
        }
      }else{
        $logFileO.Ignored="FALSE"
        write-host "THIS IS A TEST -  NOT IGNORING $useremail"
      }
      }

      }else{
# If not a test, do the deed of deletion

If ($ignoreUsers="TRUE")
{
  If (@($ignoreArray).Count -ne 0)
  {
  # if in array, ignore
  If ($ignoreArray.Contains($useremail))
  {
  $logFileO.Ignored="TRUE"
  write-host "Ignoring the user."
  }else{
    $logFileO.Ignored="FALSE"
    op delete user $useremail
  }
}else{
  $logFileO.Ignored="FALSE"
  op delete user $useremail
}

}
}

# If not suspended, no action needed, log they are not suspended and move along
  }else{
    $logFileO.Ignored     ="TRUE"
    $logFileO.NeedRemoval = "FALSE"
  }

  # Confirm user deletion
# If a test, output this is a test, and the email for visual representation
  If ($runTest -eq 1)
  {
write-host "THIS IS A TEST -  USER NOT DELETED"
# It is a test, so obviously the user is not deleted
  $logFileO.ConfirmRemoval="NOT REMOVED"
  }else{
# If not a test, we will check a freshly made user list for the email and report back using the function above
# We check EVERY user as a precaution
  $1passCheck = checkUSer $useremail # Check if user exists in 1pass
  if ($1passCheck -eq "FALSE") {
# If the user IS NOT found, it is returned as false, and logged as REMOVED
  $logFileO.ConfirmRemoval="REMOVED"
  }else{
# If the user IS found, they are not removed. This will let us review logs
  $logFileO.ConfirmRemoval="NOT REMOVED"
  }
}

# Outputs all information for the user (based on the log array)
  $logFileO
# Outputs the log array to the csv
  $logFileO | Export-CSV $1pImportFile -Append -NoTypeInformation -Force

# Shows some speration for better visuals
next_line
write-host "----------"
next_line
}


}

# Outputs all information for the user (based on the log array)
  $logFileO
# Outputs the log array to the csv
  $logFileO | Export-CSV $1pImportFile -Append -NoTypeInformation -Force

# end forloop
}





# --------

getTXT

if (Test-Path $1pfile -PathType leaf)
{
  If ($runTest -eq 1)
  {
processText
createLOG
processUsers
}else{
  Write-Warning "This is not a test, do you wish to run?"
  $askRun = Read-Host -Prompt '(y/n) '
  if($askRun -eq "y")
  {
    processText
    createLOG
    processUsers
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
