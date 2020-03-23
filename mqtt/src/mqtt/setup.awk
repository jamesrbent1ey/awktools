############### execution ##################
function mqttSetup(   i,s) {
   delete MQTT_CHAR_TO_INT
   for(i=0; i<256; i++) {
      s = sprintf("%c", i)
      MQTT_CHAR_TO_INT[s] = i
   }
   delete MQTT_INT_TO_CHAR
   for(i=0; i<256; i++) {
      s = sprintf("%c", i)
      MQTT_CHAR_TO_INT[i] = s
   }
   # setup the queue
   MQTT_INPUT_QUEUE = "mqttsq"
   if(!fileExists(MQTT_INPUT_QUEUE)) {
      #executeCommand("rm -f "MQTT_INPUT_QUEUE)
      executeCommand("mkfifo "MQTT_INPUT_QUEUE)
   }
   
   # connection config
   #TODO read these in
   #IOTHUBHOSTNAME is in connection string (HostName=), so is device name (DeviceId-) and
   #signature/SAS token/password (SharedAccessKey=)
   #endpoint for websockets is 443, 8883 is for mqtt
   MQTT_ENDPOINT = IOTHUBHOSTNAME":8883"
   MQTT_USERNAME = IOTHUBHOSTNAME"/"IOTDEVICENAME"/?api-version=2018-06-30"
   MQTT_PASS = ""
   # client id utf8 encoded
   MQTT_CLIENT_ID = ""

   # initialize values
   MQTT_MESSAGE_TYPE_CONNECT = 1
   MQTT_MESSAGE_TYPE_CONNACK = 2
   MQTT_MESSAGE_TYPE_PUBLISH = 3
   MQTT_MESSAGE_TYPE_PUBACK = 4
   MQTT_MESSAGE_TYPE_PUBREC = 5
   MQTT_MESSAGE_TYPE_PUBREL = 6
   MQTT_MESSAGE_TYPE_PUBCOMP = 7
   MQTT_MESSAGE_TYPE_SUBSCRIBE = 8
   MQTT_MESSAGE_TYPE_SUBACK = 9
   MQTT_MESSAGE_TYPE_UNSUBSCRIBE = 10
   MQTT_MESSAGE_TYPE_UNSUBACK = 11
   MQTT_MESSAGE_TYPE_PINGREQ = 12
   MQTT_MESSAGE_TYPE_PINGRESP = 13
   MQTT_MESSAGE_TYPE_DISCONNECT = 14
   
   MQTT_QOS_AT_MOST_ONCE = 0
   MQTT_QOS_AT_LEAST_ONCE = 1
   MQTT_QOS_EXACTLY_ONCE = 2
   
   MQTT_KEEP_ALIVE_INTERVAL = 60
}
function processCmdLine(    a, i, s) {   
    if (ARGV[1] == "send") {
       # call this with 'send' requires an additional
       # parameter that represents the decimal encoded
       # string with each character separated by '.'
       # example: ./mqtt.awk send 104.101.108.108.111
       #          the above posts hello to the queue
       # this enables non-block posts to the queue
       if(ARGC <= 2) {
          print "usage: ./mqtt.awk send <. delimited decimal str>"
       }
       delete a
       split(ARGV[2],a,".")
       s = ""
       for(i=1; i <= length(a); i++){
          s = sprintf("%s%c",s,a[i])
       }
       printf(s) > MQTT_INPUT_QUEUE
       return
    }
    
    # tests below
    if(ARGV[1] == "testprime") {
        print "priming"
        MQTT_USERNAME = "uname"
        MQTT_PASS = "pass"
        MQTT_CLIENT_ID = "client"
        mqttPrimeConnection()
        print "primed"
        return
    } 
    if(ARGV[1] == "testsub") {
        print "subscribing"
        delete a
        delete s
        # cfg - configuration array, must contain topic+qos array
        #       cfg["subTopics"] = [["topic",qos],...]
        #delete a["subTopics"]
        #delete a["subTopics"][1]
        a["subtopicCount"] = 1
        a["subTopics", 1, 1] = "helloTopic"
        a["subTopics", 1, 2] = 0
        mqttBuildSubscribeMessage(a, s)
        print "subscription: "
        dumpHex(s)
        return
    }  
    if(ARGV[1] == "testunsub") {
        print "unsubscribing"
        delete a
        delete s
        # cfg - configuration array, must contain topic+qos array
        #       cfg["subTopics"] = [["topic",qos],...]
        #delete a["subTopics"]
        #delete a["subTopics"][1]
        a["subtopicCount"] = 1
        a["subTopics", 1, 1] = "helloTopic"
        mqttBuildUnsubscribeMessage(a, s)
        print "unsubscription: "
        dumpHex(s)
        return
    } 
    if (ARGV[1] == "test") {
       #system("((echo -ne '\x68\x65\x6c\x6c\x6f') > mqttsq) &");
       # biggest problem with this approach is threading can
       # intermingle characters.
       delete a
       split("104.101.108.108.111",a,".")
       s = ""
       for(i=1; i <= length(a); i++){
          #printf("%c",a[i]) > "./mqttsq"
          s = sprintf("%s%c",s,a[i])
       }
       # this approach appears to work well and 
       # reduces chance of error due to threading
       printf(s) > "./mqttsq"
       return
    }
    if (ARGV[1] == "testpingreq") {
       delete a
       mqttBuildPingReq(a)
        print "ping: "
        dumpHex(a)
       return
    }
    if (ARGV[1] == "testpub") {
        delete a
        a["retain"] = (1==0)
        a["duplicate"] = (1==0)
        a["qos"] = 0
        a["topic"] = "/test"
        a["payload"] = "hello"
        delete s
        mqttBuildPubMessage(a,s)
        dumpHex(s)
        delete a
        a["retain"] = (1==1)
        a["duplicate"] = (1==0)
        a["qos"] = 0
        a["topic"] = "/test"
        a["payload"] = "hello"
        delete s
        mqttBuildPubMessage(a,s)
        dumpHex(s)
        delete a
        a["retain"] = (1==0)
        a["duplicate"] = (1==1)
        a["qos"] = 0
        a["topic"] = "/test"
        a["payload"] = "hello"
        delete s
        mqttBuildPubMessage(a,s)
        dumpHex(s)
        delete a
        a["retain"] = (1==0)
        a["duplicate"] = (1==0)
        a["qos"] = 2
        a["topic"] = "/test"
        a["payload"] = "hello"
        delete s
        mqttBuildPubMessage(a,s)
        dumpHex(s)
       return
    }
    if (ARGV[1] == "test2") {
       if(!fileExists(MQTT_INPUT_QUEUE)) {
          print "not present"
       } else {
          print "exists"
       }
       return
    }
}
#
