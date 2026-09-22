<?php
    include "TopSdk.php";
    date_default_timezone_set('Asia/Shanghai'); 

    $httpdns = new HttpdnsGetRequest;
    $client = new ClusterTopClient("YOUR_ALIYUN_APP_KEY","YOUR_ALIYUN_APP_SECRET");
    $client->gatewayUrl = "http://api.daily.taobao.net/router/rest";
    var_dump($client->execute($httpdns,"YOUR_ALIYUN_ACCESS_TOKEN"));

?>