$deconzIP = "<IP>"
$apiKey = "<key>"

$wl = (Invoke-WebRequest -uri "http://$deconzIP/api/$apikey/config" -UseBasicParsing).content
$jwl = $wl | convertfrom-json -Depth 999
foreach($key in ($jwl.whitelist | get-member -MemberType NoteProperty ).name){
    if($jwl.whitelist.$key."last use date" -lt (get-date).adddays(-7)){
        Invoke-WebRequest -uri "http://$deconzIP/api/$apikey/config/whitelist/$key" -UseBasicParsing -Method Delete
    }
}


