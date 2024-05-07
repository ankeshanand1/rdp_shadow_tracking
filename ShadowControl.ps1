# Author: Ankesh Anand
# Email: ankesh@lhytechnologies.com
# Copyright LHY Technologies

function Select-TextItem 
{ 
PARAM  
( 
    [Parameter(Mandatory=$true)] 
    $options, 
    $displayProperty 
) 
 
    [int]$optionPrefix = 1 
    # Create menu list 
    foreach ($option in $options) 
    { 
        if ($displayProperty -eq $null) 
        { 
            Write-Host ("{0,3}: {1}" -f $optionPrefix,$option) 
        } 
        else 
        { 
            Write-Host ("{0,3}: {1}" -f $optionPrefix,$option.$displayProperty) 
        } 
        $optionPrefix++ 
    } 
    Write-Host ("{0,3}: {1}" -f 0,"To cancel")  
    [int]$response = Read-Host "Select which server to Shadow" 
    $val = $null 
    if ($response -gt 0 -and $response -le $options.Count) 
    { 
        $val = $options[$response-1] 
    } 
    return $val 
}    
 
$values = "WIN-HM4KMCQEH2D","etc..."
$val = Select-TextItem $values 
$val 

Function Get-ActiveSessions{
    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [string]$Name
        ,
        [switch]$Quiet
    )
    Begin{
        $return = @()
    }
    Process{
        If(!(Test-Connection $Name -Quiet -Count 1)){
            Write-Error -Message "Unable to contact $Name. Please verify its network connectivity and try again." -Category ObjectNotFound -TargetObject $Name
            Return
        }
        If([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")){ #check if user is admin, otherwise no registry work can be done
            #the following registry key is necessary to avoid the error 5 access is denied error
            $LMtype = [Microsoft.Win32.RegistryHive]::LocalMachine
            $LMkey = "SYSTEM\CurrentControlSet\Control\Terminal Server"
            $LMRegKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($LMtype,$Name)
            $regKey = $LMRegKey.OpenSubKey($LMkey,$true)
            If($regKey.GetValue("AllowRemoteRPC") -ne 1){
                $regKey.SetValue("AllowRemoteRPC",1)
                Start-Sleep -Seconds 1
            }
            $regKey.Dispose()
            $LMRegKey.Dispose()
        }
        $result = qwinsta /server:$Name
        If($result){
            ForEach($line in $result[1..$result.count]){ #avoiding the line 0, don't want the headers
                $tmp = $line.split(" ") | ?{$_.length -gt 0}
                If(($line[19] -ne " ")){ #username starts at char 19
                    If($line[48] -eq "A"){ #means the session is active ("A" for active)
                        $return += New-Object PSObject -Property @{
                            "ComputerName" = $Name
                            "SessionName" = $tmp[0]
                            "UserName" = $tmp[1]
                            "ID" = $tmp[2]
                            "State" = $tmp[3]
                            "Type" = $tmp[4]
                        }
                    }Else{
                        $return += New-Object PSObject -Property @{
                            "ComputerName" = $Name
                            "SessionName" = $null
                            "UserName" = $tmp[0]
                            "ID" = $tmp[1]
                            "State" = $tmp[2]
                            "Type" = $null
                        }
                    }
                }
            }
        }Else{
            Write-Error "Unknown error, cannot retrieve logged on users"
        }
    }
    End{
        If($return){
            If($Quiet){
                Return $true
            }
            Else{
                Return $return
            }
        }Else{
            If(!($Quiet)){
                Write-Host "No active sessions."
            }
            Return $false
        }
    }
}

Get-ActiveSessions $val | Where-Object -Property State -EQ 'Active'

$sessionid=Read-Host -Prompt "Please input session number to shadow"


Mstsc.exe /V:$val /shadow:$sessionid /control /noConsentPrompt