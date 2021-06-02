$aem_host                       = "yourserver.youdomain.com"
$aem_username                   = "_dbtask@companyxyz.com"
$aem_password                   = "SecuredPassWord"
$aem_sessionid                  = ""
$aem_server                     = ""
$aem_url_login                  = "https://" + $aem_host + "/attunityenterprisemanager/api/v1/login"
$aem_url_servers                = "https://" + $aem_host + "/attunityenterprisemanager/api/v1/servers"
$aem_username_password_bytes    = [System.Text.Encoding]::UTF8.GetBytes($aem_username + ":" + $aem_password)
$aem_username_password_base64   = [System.Convert]::ToBase64String($aem_username_password_bytes)

# Parameters to be passed when the program is called 
$aem_parameters_action                                    = $args[0]
$aem_parameters_target_replicate_server                   = $args[1]
$aem_parameters_target_replicate_server_country           = $args[2]
$aem_parameters_target_replicate_server_action            = $args[3]
$aem_parameters_debugmode                                 = $args[4]
$aem_parameters_debugmode_taskname                        = $args[5]
# Addtitonal Parameters 
$aem_paramaeters_export_base_path           = "\\youdomain\resources$\SomePathOnNetwork"
$aem_paramaeters_export_base_path_script_name = $MyInvocation.MyCommand.Name -replace ".ps1" ,""
$aem_paramaeters_export_base_path_log       = "\\youdomain\resources$\Database_Scripts\Attunity\Log\aem-api-code\"
$aem_paramaeters_export_base_path_export    = "\\youdomain\resources$\Database_Scripts\Attunity\export\aem-api-code\"
$aem_parameters_export_serverlist           = "aemserverlist.json"
$aem_parameters_export_server_definition    = "aemstasklist"
$outputfile = "$aem_paramaeters_export_base_path_log$aem_paramaeters_export_base_path_script_name"+"_"+"$aem_parameters_target_replicate_server"+"_"+"$aem_parameters_target_replicate_server_country"+"_"+"$aem_parameters_target_replicate_server_action"+"_"+"$(get-date -f yyyy-MM-dd-HH-mm-ss).log"
$pattern                                    = "DDW_$($aem_parameters_target_replicate_server_country)_*"
$pattern2                                   = "ETL__$($aem_parameters_target_replicate_server_country)_*" 

Start-Transcript -Path $outputfile -NoClobber
if ($aem_parameters_debugmode -eq 1) {
Write-Host "You passed Parameter for aem_paramaeters_export_base_path_script_name:"   $aem_paramaeters_export_base_path_script_name   
Write-Host "You passed Parameter for aem_url_login:"                                  $aem_url_login                         
Write-Host "You passed Parameter for aem_username_password_bytes:"                    $aem_username_password_bytes                         
Write-Host "You passed Parameter for aem_username_password_base64:"                   $aem_username_password_base64                         
Write-Host "You passed Parameter for aem_parameters_action:"                          $aem_parameters_action                         
Write-Host "You Passed Parameter for aem_parameters_target_replicate_server:"         $aem_parameters_target_replicate_server        
Write-Host "You Passed Parameter for aem_parameters_target_replicate_server_country:" $aem_parameters_target_replicate_server_country
Write-Host "You Passed Parameter for aem_parameters_target_replicate_server_action:"  $aem_parameters_target_replicate_server_action 
}
#Write-Host $pattern
if ($aem_parameters_debugmode_taskname) { Write-Host *********** Single Task Mode **********}

# Parameter Validation
    if (("IPL","") -contains $aem_parameters_action )   {} else {
      Write-Host "Invalid paramater value for aem_parameters_action. You passed:" $aem_parameters_action 
    Write-Host "Valid values are: IPL or Blank"
      Exit
    }
    if (("AS400_PRD", "AS400_UAT", "AS400_DEV") -contains $aem_parameters_target_replicate_server ) { } else {
      Write-Host "Invalid paramater value for aem_parameters_target_replicate_server. You passed:" $aem_parameters_target_replicate_server 
    Write-Host "Valid values are REPLICATESERVER_ONE or REPLICATESERVER_ONE_UAT"
      Exit
    }   
    if (("US", "CA") -contains $aem_parameters_target_replicate_server_country ) { } else {
      Write-Host "Invalid paramater value for aem_parameters_target_replicate_server_country. You passed:" $aem_parameters_target_replicate_server_country 
      Write-Host "Valid values are US or CA"
      Exit
    }   
    if (("stop", "start", "details") -contains $aem_parameters_target_replicate_server_action ) { } else {
      Write-Host "Invalid paramater value for aem_parameters_target_replicate_server_action. You passed:" $aem_parameters_target_replicate_server_action 
      Write-Host "Valid values are Stop or Start or Details"
      Exit
    }                   

# Retrieve session id which is valid for 5 mins
  Try {    
        $aem_params = @{
          Uri     = $aem_url_login
          Headers = @{ 'Authorization' = "Basic $aem_username_password_base64" }
          Method  = 'GET'
        }
        $aem_response_login = Invoke-RestMethod @aem_params -ResponseHeadersVariable headers
        $aem_response_login | Format-Table
        $aem_sessionid = $headers. 'EnterpriseManager.APISessionID'
        if ($aem_parameters_debugmode -eq 1) { 
          Write-Host "Succcessfully connected to AEM API; APISessionID " $aem_sessionid
          Write-Host "Try block called the API via URL:  $aem_url_login "}
      }
  Catch 
      {
        Write-Host $_.Exception.Message`n
      }

# Extract the servers list
Try 
  {  
      $aem_response_servers = Invoke-RestMethod -Uri $aem_url_servers -Method Get -Headers @{ 'EnterpriseManager.APISessionID' = '' + $aem_sessionid + '' } | ConvertTo-Json -Depth 50
      $aem_response_servers | Out-File $aem_paramaeters_export_base_path_export$aem_parameters_export_serverlist
      
      if ($aem_parameters_debugmode -eq 1) 
        { 
        Write-Host "Try block called the API via URL:  $aem_url_servers " 
        Write-Host "Succcessfully extracted replicate servers list to " $aem_paramaeters_export_base_path_export$aem_parameters_export_serverlist
        }
  }
Catch 
  {
      Write-Host $_.Exception.Message`n
  }

#Processing starts
    $x = $aem_response_servers | ConvertFrom-Json
    $serverList_names = $x.serverList.Name 
    if ($aem_parameters_debugmode -eq 1) { Write-Host "Found" $serverList_names.Count "replicate servers."}
    $aem_url_tasklist_response = @()
    Write-Host $("#" * 100)
    try {
      foreach ($item in $serverList_names) 
      {
        $aem_server = $item
          if ($aem_parameters_debugmode -eq 1) { Write-Host "Executing foreach block for:  $item " }
        $aem_url_tasklist             = "https://" + $aem_host + "/attunityenterprisemanager/api/v1/servers/" + $aem_server + "/tasks"
        if ($aem_parameters_debugmode -eq 1) { Write-Host "Try block called the API via URL:  $aem_url_tasklist " } 
        $aem_url_tasklist_response    = Invoke-RestMethod -Uri $aem_url_tasklist -Method Get -Headers @{ 'EnterpriseManager.APISessionID' = '' + $aem_sessionid + '' } 
        $aem_url_tasklist_response | ConvertTo-Json -Depth 50 | Out-File $aem_paramaeters_export_base_path_export$aem_parameters_export_server_definition$item.json
        if ($aem_parameters_debugmode -eq 1) { 
        Write-Host "Task details extracted for replicate server" $item
        Write-Host "Export written to "$aem_paramaeters_export_base_path_export$aem_parameters_export_server_definition$item.json
        }
      
# For IPL dig into a specific replicate server for performing certain actions on them
  #Write-Host "Replicate Server"$item "found.."
    if ($item -eq $aem_parameters_target_replicate_server) {
       Write-Host "Replicate Server"$item "found.."
       $t = 0
       $aem_url_task_start_cdc_position  = (Get-Date ([datetime]::UtcNow)).AddMinutes(-$t) | Get-Date  -UFormat %Y-%m-%dT%H:%M:%S
	        if($aem_parameters_target_replicate_server_action -eq "start"){
            Write-Host 'Advanced start requested with CDC position = Current Time -(minus)'$t' minutes' 
            Write-Host 'Calculated CDC position in UTC:' $aem_url_task_start_cdc_position
          }
	        if($aem_parameters_target_replicate_server_action -eq "stop"){Write-Host 'Stop requested'}
              $y = $aem_url_tasklist_response | ConvertTo-Json -Depth 50 #|  Out-File $aem_paramaeters_export_base_path_export$aem_parameters_export_server_definition$item"temp.json"
              $z = $y | ConvertFrom-Json
     
      function Get-AllTasksInConsistentState(){
            $AllTasksInConsistentState = $true
            if(!$aem_parameters_debugmode_taskname){
              ForEach ($item in $z.taskList.Name){
                  if ($item -like $pattern -or $item -like $pattern2){
                    #Write-Host 'Check to see if all the tasks are in a valid & consistent state'
					if ($aem_parameters_debugmode -eq 1) { Write-Host "item is " $item}
                    $aem_response_taskstatus = @()
                    $aem_url_taskstatus = "https://" + $aem_host + "/attunityenterprisemanager/api/v1/servers/" + $aem_server + "/tasks/"+$item
					if ($aem_parameters_debugmode -eq 1) { Write-Host "aem_url_taskstatus is " $aem_url_taskstatus}
                    $aem_response_taskstatus = Invoke-RestMethod -Uri $aem_url_taskstatus -Method Get -Headers @{ 'EnterpriseManager.APISessionID' = '' + $aem_sessionid + '' } 
                    $tasknamestate = $aem_response_taskstatus |ConvertTo-Json -Depth 50 |  ConvertFrom-Json |  select name, state
                    #remove below line after testing
                    #Write-Host "Considering" $tasknamestate.name
                    If ($aem_parameters_target_replicate_server_action -Like "Stop" -And $tasknamestate.state -NotLike "RUNNING") {
                      Write-Host $tasknamestate.name "Found to be in a >>" $tasknamestate.state "<< state. All tasks must be in RUNNING state"
                      $AllTasksInConsistentState = $false
                      return $AllTasksInConsistentState
                    }
                    else{
                    If ($aem_parameters_target_replicate_server_action -Like "Start" -And $tasknamestate.state -NotLike "STOPPED") {
                        Write-Host $tasknamestate.name "Found to be in a >>" $tasknamestate.state "<< state. All tasks must be in STOPPED state"  
                      $AllTasksInConsistentState = $false
                      return $AllTasksInConsistentState
                    }
                    }

                       #Write-Host "AllTasksInConsistentState: " $AllTasksInConsistentState
                  }


              }
              
            }
            return $AllTasksInConsistentState
      }
      
      Write-Host 'Check to see if all the tasks are in a valid & consistent state:'
      $AllTasksInConsistentState = Get-AllTasksInConsistentState
            #write-host "Line 163"
      Write-Host "AllTasksInConsistentState is" $AllTasksInConsistentState   

      if ($AllTasksInConsistentState -eq $false) { 
        Write-Host "Not taking the action requested, check to see if all the tasks are in a valid & consistent state. Ex: All tasks must be in a RUNNING state before stopping & vice versa." 
         exit 999
      }
      #write-host "Line 166"
       $z_pattern_match = @()
      $z_pattern_match = $z.taskList.Name | Where-Object { $_ -Match $pattern -or $item -Match $pattern2 }
      #write-host "Line 169"
      function Get-latency () {

      #write-host "invoke1"
      if (!$aem_parameters_debugmode_taskname) {
        #write-host "invoke2"
          
          #Write-host $AllTasksInConsistentState
          if (($AllTasksInConsistentState -eq $true ) -and ($aem_parameters_target_replicate_server_action -eq "stop")) {
            #write-host "invoke3"
            #do{
              #$i = $z_pattern_match.Length+1
            ForEach ($item in $z_pattern_match) {
              #write-host "invoke4"

                          if ($item -like $pattern -or $item -like $pattern2)
                          #if ($item -eq 'DDW_US_DM4JRN')
                          {
                                              
              
                                                #Write-Host $AllTasksInConsistentState
                                                #Write-Host $aem_parameters_target_replicate_server_action
                                                #Write-Host "Item is now" $item
                                                #$i--
                                                #Write-Host $i
                                          
                                                $aem_response_taskstatus = @()
                                                $aem_url_taskstatus = "https://" + $aem_host + "/attunityenterprisemanager/api/v1/servers/" + $aem_server + "/tasks/"+$item
                                                #Write-Host $aem_url_taskstatus
                                                $aem_response_taskstatus = Invoke-RestMethod -Uri $aem_url_taskstatus -Method Get -Headers @{ 'EnterpriseManager.APISessionID' = '' + $aem_sessionid + '' } 
                                                
                                                $total_latency = $aem_response_taskstatus | ConvertTo-Json -Depth 50 |  ConvertFrom-Json |  select -expand cdc_latency | select total_latency,source_latency
                                                

                                                $taskdetails_cdc = $aem_response_taskstatus | ConvertTo-Json -Depth 50 |  ConvertFrom-Json |  select -expand cdc_transactions_counters | select commit_change_records_count,
                                                      rollback_transaction_count,
                                                      rollback_change_records_count,
                                                      rollback_change_volume_mb,
                                                      applied_transactions_in_progress_count,
                                                      applied_records_in_progress_count,
                                                      applied_comitted_transaction_count,
                                                      applied_records_comitted_count,
                                                      applied_volume_comitted_mb,
                                                      incoming_accumulated_changes_in_memory_count,
                                                      incoming_accumulated_changes_on_disk_count,
                                                      incoming_applying_changes_in_memory_count,
                                                      incoming_applying_changes_on_disk_count
                                                
                                                #Write-Host $aem_response_taskstatus
                                                #$Waitfor_Seconds = 30
                                                #$x = $true
                                                #Write-Host $aem_response_taskstatus
                                                #Write-Host $item
                                                #Write-Host $total_latency.total_latency.ToString()
                                                #Write-Host $taskdetails_cdc.applied_records_in_progress_count.ToString()
                                                if (
                                                    $total_latency.total_latency.ToString() -ne '00:00:00'  -or 
                                                    $total_latency.source_latency.ToString() -ne '00:00:00' -or 
                                                    $taskdetails_cdc.applied_transactions_in_progress_count.ToString() -ne '0' -or
                                                    $taskdetails_cdc.applied_records_in_progress_count.ToString() -ne '0' -or
                                                    $taskdetails_cdc.incoming_accumulated_changes_in_memory_count.ToString() -ne '0' -or
                                                    $taskdetails_cdc.incoming_accumulated_changes_on_disk_count.ToString() -ne '0' -or
                                                    $taskdetails_cdc.incoming_applying_changes_in_memory_count.ToString() -ne '0' -or
                                                    $taskdetails_cdc.incoming_applying_changes_on_disk_count.ToString() -ne '0' 
                                                    ) 
                                                  { #$isLatencyZero = $false
                                                    #Write-Host "invoked false"
                                                    Write-Host $item
                                                    Write-Host total_latency                                $total_latency.total_latency.ToString()
                                                    Write-Host source_latency                               $total_latency.source_latency.ToString()
                                                    Write-Host applied_transactions_in_progress_count       $taskdetails_cdc.applied_transactions_in_progress_count.ToString()
                                                    Write-Host applied_records_in_progress_count            $taskdetails_cdc.applied_records_in_progress_count.ToString()
                                                    Write-Host incoming_accumulated_changes_in_memory_count $taskdetails_cdc.incoming_accumulated_changes_in_memory_count.ToString()
                                                    Write-Host incoming_accumulated_changes_on_disk_count   $taskdetails_cdc.incoming_accumulated_changes_on_disk_count.ToString()
                                                    Write-Host incoming_applying_changes_in_memory_count    $taskdetails_cdc.incoming_applying_changes_in_memory_count.ToString()
                                                    Write-Host incoming_applying_changes_on_disk_count      $taskdetails_cdc.incoming_applying_changes_on_disk_count.ToString()
                                                    

                                                    return $false
                                                  } 
                                                  #  else {
                                                  #    if (($isLatencyZero -ne $true) -and ($i -eq 1 )){
                                                  #    Write-Host "invoked true"
                                                  #    $isLatencyZero = $true
                                                  #    return $isLatencyZero
                                                  #    }
                                                  #  }

                          }
                }
                #Write-Host "invoked true"
                #$isLatencyZero = $true
                return $true
               }
               
            }
      }
      #write-host "Line 266"
      function Get-LatencyClearanceBeforeStopping() {
        #Write-Host "Invoking ..Get-LatencyClearanceBeforeStopping"
        $isLAtencyZeroHashTable = [ordered]@{ isLAtencyZeroTrue = 0; isLAtencyZeroFalse = 0 }
        #$isLAtencyZeroHashTable
        for ($itr = 1; $itr -lt 21; $itr++) {
    
          #if ($itr % 2 -eq 0) { $isLatencyZero = $false } else { $isLatencyZero = $true}     # should exit false afert itr 20
          #if ($itr -in 1..4 ) { $isLatencyZero = $true } else { $isLatencyZero = $false}     # should exit false after itr 9
          #if ($itr -in 1..3 ) { $isLatencyZero = $false } else { $isLatencyZero = $true }    # should exit true after itr 8
          #$isLatencyZero = $true                                                             # should exit true after itr 5
          #$isLatencyZero = $false                                                            # should exit false after itr 5
          
          $isLatencyZero = Get-latency
          #Write-Host "Line 258"
          #Write-Host $isLatencyZero.Gettype()
          Write-Host 'Latency Check No:' $itr ' Is Latency Zero?' $isLatencyZero
          #$isLAtencyZeroHashTable
    
          if ($itr -eq 1 ) {
            $lastseen = $isLatencyZero 
          }

          if ($isLatencyZero -eq $lastseen) { 
            if ($isLatencyZero -eq $true) {
              $isLAtencyZeroHashTable['isLAtencyZeroTrue']++ 
            } 
            else {
              $isLAtencyZeroHashTable['isLAtencyZeroFalse']++ 
            } 
          }
          else {
            if ($isLatencyZero -eq $true) {   
              $isLAtencyZeroHashTable['isLAtencyZeroTrue']++ 
              $isLAtencyZeroHashTable['isLAtencyZeroFalse'] = 0 
            }
            else {
              $isLAtencyZeroHashTable['isLAtencyZeroFalse']++ 
              $isLAtencyZeroHashTable['isLAtencyZeroTrue'] = 0
            }
          }

    
          if ($isLAtencyZeroHashTable['isLAtencyZeroTrue'] -ge 3) {
            #$isLAtencyZeroHashTable
            #Write-Host 'Latency is staying zero, please proceed to stop'    
            #$isLatencyZero = $true
            return $true
          }
          if ($isLAtencyZeroHashTable['isLAtencyZeroFalse'] -ge 3) {
            #$isLAtencyZeroHashTable
            #Write-Host 'Latency not going down, Please call Database POC'    
            #$isLatencyZero = $false
            return $false
          }
          if ($itr -eq 20 ) {
            #Write-Host 'a consistent true or false was not acheived' 
            #$isLatencyZero = $false
            return $false
          }

          $lastseen = $isLatencyZero
          Start-Sleep 15
        }
    

      }
      
      # write-host "Line 334"
      $LatencyClearance = $true
      if (($AllTasksInConsistentState -eq $true) -and $aem_parameters_target_replicate_server_action -eq "stop")
      {
        write-host "calling LatencyClearanceBeforeStopping"
        $LatencyClearance = Get-LatencyClearanceBeforeStopping
        Write-Host "LatencyClearance is" $LatencyClearance
      }

      function Get-TimeWindowCheck(){
        $min = Get-Date '00:00'
        $max = Get-Date '23:59'
        $now = Get-Date

        if ($min.TimeOfDay -le $now.TimeOfDay -and $max.TimeOfDay -ge $now.TimeOfDay) {
          return $true
        }
        else { return $false}
      }

     
      $TimeWindowCheck = $true
      if (($AllTasksInConsistentState -eq $true) -and $aem_parameters_target_replicate_server_action -eq "start") {
        write-host "calling TimeWindowCheck"
        $TimeWindowCheck = Get-TimeWindowCheck
        Write-Host "TimeWindowCheck is" $TimeWindowCheck
      }

      
      #Start-Sleep 50
      #Write-Host "line 352"
      $z.taskList.Name | ForEach-Object -Parallel { 
        #Write-Host "line 354"
        #  Write-Host "Line 355" $using:aem_parameters_target_replicate_server_action
        #  Write-Host "Line 356" $using:AllTasksInConsistentState
          #Write-Host "Line 359" $_
          #Write-Host "Line 360 pattern:" $using:pattern
          #Write-Host "Line 361 pattern2" $using:pattern2
          #$_ -like $using:pattern

        # Testing the program on only one task -- BEGIN
        # Uncomment the line if ($item = 'I_CA_ATUJRN') {
        # if ($item = 'I_CA_ATUJRN') {
        #Write-Host "TESTTTTT"
        #Write-Host $using:aem_parameters_target_replicate_server_country
        #Write-Host $using:aem_parameters_target_replicate_server_action
        
        #Write-Host $p

        #if ($_ -like $using:pattern -and $using:aem_parameters_action -eq "IPL" -and $using:AllTasksInConsistentState -eq $TRUE ) 
        if (($_ -like $using:pattern -or $_ -like $using:pattern2 ) -and $using:AllTasksInConsistentState -eq $TRUE ) 
        #if ($_ -like $using:pattern  -and $using:AllTasksInConsistentState -eq $TRUE ) 
          {
            #Write-Host "Line 373"
            Start-Sleep -s 15
            if ( ($using:aem_parameters_debugmode_taskname) -and ($_ -ne $using:aem_parameters_debugmode_taskname)) { return}
             #Write-Host "Line 326"
            # Write-Host "Line 327" $using:aem_parameters_target_replicate_server_action
            #Write-Host "Line 328" $using:LatencyClearance
          # IPL Actions by task -- BEGIN
            
            $aem_url_task_stop                = "https://" + $using:aem_host + "/attunityenterprisemanager/api/v1/servers/" + $using:aem_server + "/tasks/" + $_ + "/?action=stop&timeout=240"
            $aem_url_task_details             = "https://" + $using:aem_host + "/attunityenterprisemanager/api/v1/servers/" + $using:aem_server + "/tasks/" + $_
            $aem_url_task_start               = "https://" + $using:aem_host + "/attunityenterprisemanager/api/v1/servers/" + $using:aem_server + "/tasks/" + $_ + "/?action=run&option=RESUME_PROCESSING_FROM_TIMESTAMP&timeout=540"
            
                          if($using:aem_parameters_target_replicate_server_action -eq "stop"){

                             #Write-Host "line 379"
                            if($using:LatencyClearance  -eq $true){
							                #Write-Host "373"
                              #Write-Host LatencyClearance $using:LatencyClearance
                                if ($using:aem_parameters_debugmode -eq 1) { Write-Host $aem_url_task_stop}
                                  try { 
                                    Write-Host "Executing" $using:aem_parameters_target_replicate_server_action "on task" $_
                                    $aem_url_task_stop_response = Invoke-RestMethod -Uri $aem_url_task_stop -Method POST -Headers @{ 'EnterpriseManager.APISessionID' = '' + $using:aem_sessionid + '' }
                                    Write-Host $aem_url_task_stop_response
                                    $aem_url_task_stop_response | ConvertTo-Json
                                    Write-Host "$_ - stopped successfully"
                                  }
                                  catch {
                                    Write-Host "$_ might already be stopped"
                                    exit 999
                                    
                                  }
                                }
                              else 
                              {
                                 Write-Host "Not taking the action requested, Could not get Latency Clearance Before Stopping the tasks, make sure all task latencies are zero and try again."
                                 exit 999
                              }
                            }


                          if($using:aem_parameters_target_replicate_server_action -eq "details"){
                          
                            if ($using:aem_parameters_debugmode -eq 1) { Write-Host $aem_url_task_details}
                              try { 
                                    #Write-Host 'Check to see if all the tasks are in a valid & consistent state'
                                    Write-Host "Executing" $using:aem_parameters_target_replicate_server_action "on task" $_
                                    $aem_response_taskstatus = @()
                                    $aem_url_taskstatus = "https://" + $using:aem_host + "/attunityenterprisemanager/api/v1/servers/" + $using:aem_server + "/tasks/" + $_
                                    Write-Host $aem_url_taskstatus


                                    $TimeStart  = Get-Date
                                    
                                    $LoopFor    = 5
                                    $waitfor    = 10
                                    
                                    $TimeEnd = $timeStart.addminutes($LoopFor)
                                    
                                    Write-Host "Start Time: $TimeStart"
                                    write-host "End Time:   $TimeEnd"
                                    write-host "Loop for Minutes:   $loopfor"
                                    write-host "Wait for Seconds:   $waitfor"

                                    do {
                                      Write-Host 'The Latency is not zero yet..'
                                         $aem_response_taskstatus = Invoke-RestMethod -Uri $aem_url_taskstatus -Method Get -Headers @{ 'EnterpriseManager.APISessionID' = '' + $using:aem_sessionid + '' } 
                                


                                         $total_latency = $aem_response_taskstatus | ConvertTo-Json -Depth 50 |  ConvertFrom-Json |  select -expand cdc_latency | select total_latency
                                         Write-Host $total_latency.total_latency
                                         

                                      Start-Sleep -Seconds $waitfor
                                    } while ( $total_latency.total_latency.ToString() -ne '00:00:00')
                                  

                              }
                              catch {
                                Write-Host "$_ Unable to Get Task Details"
                              }

                          }


                          else{
                         

                            if($using:aem_parameters_target_replicate_server_action -eq "start" ){
                               if( $using:TimeWindowCheck -eq $true)
                                {  

                                      if ($using:aem_parameters_debugmode -eq 1) { Write-Host $aem_url_task_start}
                                      try {           
                                        Write-Host "Executing" $using:aem_parameters_target_replicate_server_action "on task" $_
                                        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
                                        $headers.Add("Content-Type", "application/json")
                                        $headers.Add("EnterpriseManager.APISessionID", $using:aem_sessionid)
                                        $body = "{`"cdcposition`":`"$using:aem_url_task_start_cdc_position`"}"
                                        # $response = Invoke-RestMethod 'https://SERVERNAME.youdomain.com/attunityenterprisemanager/api/v1/servers/REPLICATESERVER_ONE_UAT/tasks/I_CA_ATUJRN/?action=run&option=RESUME_PROCESSING_FROM_TIMESTAMP' -Method 'POST' -Headers $headers -Body $body
                                        $response = Invoke-RestMethod $aem_url_task_start -Method 'POST' -Headers $headers -Body $body
                                        $response | ConvertTo-Json
                                        Write-Host "$_ - started successfully"
                                      }
                                      catch {

                                        Write-Host "$_ might already be started"
                                        # Dig into the exception to get the Response details.
                                        # Note that value__ is not a typo.
                                        #$_.Exception
                                        # Write-Host $_.Exception.GetType()
                                        # Write-Host "StatusCode:" $_.Exception.state.value__ 
                                        # Write-Host "StatusDescription:" $_.Exception.error_code
                                        exit 999
                                      }     

                                

                                  }
                                  elseif ($using:TimeWindowCheck -eq $false) 
                                    {
                              #Write-Host "Attempting to Advance start Attunity outside IPL window, STOP & contact Database POC" 
                              exit 999
                                    } 
                            }
                              
                          }
            
        }


                else{ 
                  if (($using:AllTasksInConsistentState -eq $FALSE) -and ($using:aem_parameters_action -eq "IPL") -and ($_ -like $using:pattern -or $_ -like $using:pattern2)){
                    #if ( 25 -eq 25){
                         #break Exit_out
               Write-Host "Not taking the action requested, check to see if all the tasks are in a valid & consistent state. Ex: All tasks must be in a RUNNING state before stopping & vice versa."
                exit 999
                        }
                        
                    }
        
        # IPL Actions by task -- END
        #Write-host 'some more'
        #Write-Host $using:aem_parameters_debugmode_taskname
                    if(($_ -NotMatch '[a-zA-Z]{3}_[a-zA-Z]{2}_.') -and (!$using:aem_parameters_debugmode_taskname)){
                    #if($_ -NotMatch $pattern){
                      Write-Host "Tasks with non standard names found and no action taken" $action $_  
                      #Write-Host $("~" * 70)
                    } #-ThrottleLimit 2 -AsJob
              # Testing the program on only one task
              # Uncomment the coresponding closing } for the line if ($_ = 'I_CA_ATUJRN') {
              #}
              # Testing the program on only one task -- END
              # Uncomment the break 
              #if (2 -eq 2){break}

      } -ThrottleLimit 30 -AsJob |  Receive-Job -Wait -AutoRemove
      
     }
     
    }
Write-Host $("#" * 100)
}
catch {
  Write-Host "Exception occured- Message:"
  Write-Host $_.Exception.Message`n
}

#:Exit_out do { Write-Host "Not taking the action requested, check to see if all the tasks are in a valid & consistent state. Ex: All tasks must be in a RUNNING state before stopping & vice versa." } while ( 2 -lt 1)



Stop-Transcript
