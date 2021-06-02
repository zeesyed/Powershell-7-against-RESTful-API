# powershell7_qlik_replicate_api_stop_start_advance_start
Interacting with Qlik Replicate RESTful API via Powershell 7 to control Data Replication
-----------------
_15_Seconds_Read_

Look at the **aem_start/stop_flow.pdf** file to look at the programatic flow. 

_1 min Read_

At a very high level the project is trying to solve a problem of manual interference in managing data replication across multiple disparate databases ( Oracle, SQL Server, DB2i) The code uses PowerShell 7.0 to control (stop, start, advance start) replication tasks. PowerShell interacts with Qlik/Attunity Replicate Enterprise Manager via the RESTful API.

Requirements
------------
- Powershell > 7.0
- Postman
- Curl
- Postman


This code includes the following programming features:

  * Invoke REST GET & POST methods against the API
  * Parsing the JSON for values of specific keys
  * Exploit powershell 7.0's ForEach-Object Parallel Feature , to enable multithreading
    - This is required to run several replication tasks in parallel in a for loop
    - Since this is time sensitive
  * Other programming features that can be seen are:
    - securely logging into HTTPS with Base64 Password hash
	* nested ifs & while loops
	* functions to reduce code redundancy
	* conditional logics
	* regex searches
	* error handing and exception throwing with error codes to pass on to the other porgrams ( Control-M enteprise scheduler)
