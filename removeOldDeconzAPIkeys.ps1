<#
DeConz/Phoscon automated cleanup of unused API keys.
#>

$deconzIP = "<IP>"
$apiKey = "<key>"

$webcontent = (Invoke-WebRequest -uri "http://$deconzIP/api/$apikey/config" -UseBasicParsing).content
$json = $webcontent | convertfrom-json -Depth 10
foreach($key in ($json.whitelist | get-member -MemberType NoteProperty ).name){
    if($json.whitelist.$key."last use date" -lt (get-date).adddays(-7)){
        Invoke-WebRequest -uri "http://$deconzIP/api/$apikey/config/whitelist/$key" -UseBasicParsing -Method Delete
    }
}

#finally delete the api key used to delete api keys :)
Invoke-WebRequest -uri "http://$deconzIP/api/$apikey/config/whitelist/$apikey" -UseBasicParsing -Method Delete


