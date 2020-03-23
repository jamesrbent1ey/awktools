#!/usr/bin/awk -f
################## utility #######################
function executeCommand(cmd,		result, lines) {
	lines = ""
	while( ( cmd | getline result ) > 0 ) {
		gsub(/\n/,"",result)
		gsub(/\r/,"",result)
		lines = lines result "\n"
	}
		
	#close command
	close(cmd)
	
	return lines
}
# Bitwise AND between 2 variables - var AND x
function and64(var, x,   l_res, l_i)
{
	l_res=0;
	
	for (l_i=0; l_i < 8; l_i++){
	        if (var%2 == 1 && x%2 == 1) l_res=l_res/2 + 128;
	        else l_res/=2;
	        var=int(var/2);
	        x=int(x/2);
	}
	return l_res;
}
# Rotate var left x times
function lshift64(var, x)
{
	while(x > 0){
	    var*=2;
	    x--;
	}
	return var;
}
# Rotate var right x times
function rshift64(var, x)
{
	while(x > 0){
	    var=int(var/2);
	    x--;
	}
	return var;
}
function dumpHex(arr,   i) {
   for( i = 1; i <= length(arr); i++) {
       printf("0x%.2x", arr[i])
       if(i+1 <= length(arr)) {
          printf(",")
       }
   } 
   print
}
# after much experimentation, the best approach
# appears to be to send the decimal equivalent string
# into this app, in the background.
# send an array of characters over the connection
# arr - array to send
# bkgnd - if true then asynch non-block, else blocking
function sendHex(arr, bkgnd,  i,s) {
   s = ""
   for( i = 1; i <= length(arr); i++) {
       if(i == 1)
          s = sprintf("%s%d",s,arr[i])
       else
          s = sprintf("%s.%d",s,arr[i])
   }
   if(bkgnd) {
      system("./mqtt.awk send "s" &")
   } else {
      system("./mqtt.awk send "s)
   }
}
# convert utf8 string to integer array
function strToIntArray(s,a,offset,  a2,i) {
   delete a2
   split(s,a2,"")
   for(i = 0; i < length(a2); i++) {
      a[offset+i] = MQTT_CHAR_TO_INT[a2[i+1]]
   }
}
# convert integer array to utf8 string
function intArrayToStr(a, pos, len,   s, i) {
   s = ""
   for( i = 1; i <= len; i++) {
       s = sprintf("%s%c",s,a[i+(pos-1)])
   }
   return s
}
# check for file existence
function fileExists(filename,   s) {
   s = "du "filename
   s = executeCommand(s)
   gsub(/\n/,"",s)
   if( length(s) <= 1 || index(s,"o such") > 0) {
      return 1==0
   }
   return 1==1
}
# encode a length value per spec
function mqttEncodeMBI(number, output,   numBytes, digit) {
    numBytes = 1
	do {
		digit = number % 128
		number = rshift64(number, 7)
		if (number > 0) {
			digit = or(digit,128)
		}
		output[numBytes++] = digit;
	} while ( (number > 0) && (numBytes<=4) )

    # can't return arrays but it should be populated
	#return output
}
# add src array to dst array
# src source array
# srcpos position in src to start copy from
# dst destination array
# dstpos position in dst to copy into
# cnt number of bytes to copy
function mqttAddArray(src, srcpos, dst, dstpos, cnt,    i,j) {
   j=dstpos
   for(i=srcpos; i<=(srcpos+cnt); i++) {
      dst[j] = src[i]
      j = j + 1
   }
}
# write a 16bit value into the given array MSB
# val integer to write
# dst array to write into, 2 bytes will be written
# dstpos position in dst to write the 2 bytes into
function mqttWriteUint16 (val, dst, dstpos) {
   dst[dstpos++] = and64(rshift64(val,8),255)
   dst[dstpos++] = and64(val,255)
   return dstpos
}
# read a 16bit integer from the given array
# src array to read bytes from, must be at least 2 bytes long
# srcpos position in src to read from
function mqttReadUint16 (src, srcpos    ) {
   return lshift(src[srcpos],8) + src[srcpos+1]
}
#
##################### client <-> server ###############
# Publish message
# cfg - configuration: contains
#       cfg["retain"]  required, boolean
#       cfg["duplicate"]  required, boolean
#       cfg["qos"]  required, 2 bit value
#       cfg["topic"] required, name of the topic to pub to
#       cfg["payload"] required, message to send - assumed string
function mqttBuildPubMessage(cfg, msg,   varHdr, i, flags, hex) {
   delete varHdr
   i = 1
   flags = 0
   flags = lshift64(and64(cfg["qos"],3),1)
   if(cfg["duplicate"]){
      flags = flags + 8
   }
   if(cfg["retain"]) {
      flags = flags + 1
   }
   
   # first 2 bytes is length of topic name
   mqttWriteUint16(length(cfg["topic"]),varHdr, i)
   i = i + 2
   # followed by the topic
   delete hex
   strToIntArray(cfg["topic"],hex,1)
   mqttAddArray(hex,1,varHdr,i,length(hex)-1)
   i = i + length(hex)
   
   # now the packet id
   mqttWriteUint16(mqttGetPacketId(),varHdr, i)
   i = i + 2
   
   # now we shove on the payload w/o calculating its length
   delete hex
   strToIntArray(cfg["payload"],hex,1)
   mqttAddArray(hex,1,varHdr,i,length(hex)-1)
   i = i + length(hex)
   
   i = mqttAddFixedHeader(msg, MQTT_MESSAGE_TYPE_PUBLISH, flags, length(varHdr))
   mqttAddArray(varHdr,1,msg,i,length(varHdr)-1)   
}
# build the pub ack message
# pktId id of packet being acknowledged
# msg array to hold the resulting/created message
function mqttBuildPubAckMessage(pktId, msg,    varHdr, i) {
   delete varHdr
   i = 1
   mqttWriteUint16(pktId,varHdr, i)
   i = i + 2
   
   i = mqttAddFixedHeader(msg, MQTT_MESSAGE_TYPE_PUBACK, 0, length(varHdr))
   mqttAddArray(varHdr,1,msg,i,length(varHdr)-1)   
}
# build the pub rec message
# pktId id of packet being acknowledged
# msg array to hold the resulting/created message
function mqttBuildPubRecMessage(pktId, msg,    varHdr, i) {
   delete varHdr
   i = 1
   mqttWriteUint16(pktId,varHdr, i)
   i = i + 2
   
   i = mqttAddFixedHeader(msg, MQTT_MESSAGE_TYPE_PUBREC, 0, length(varHdr))
   mqttAddArray(varHdr,1,msg,i,length(varHdr)-1)   
} 
# build the pub rel message
# pktId id of packet being released
# msg array to hold the resulting/created message
function mqttBuildPubRelMessage(pktId, msg,    varHdr, i) {
   delete varHdr
   i = 1
   mqttWriteUint16(pktId,varHdr, i)
   i = i + 2
   
   i = mqttAddFixedHeader(msg, MQTT_MESSAGE_TYPE_PUBREL, 0, length(varHdr))
   mqttAddArray(varHdr,1,msg,i,length(varHdr)-1)   
}  
# build the pub ack message
# pktId id of packet completing
# msg array to hold the resulting/created message
function mqttBuildPubCompMessage(pktId, msg,    varHdr, i) {
   delete varHdr
   i = 1
   mqttWriteUint16(pktId,varHdr, i)
   i = i + 2
   
   i = mqttAddFixedHeader(msg, MQTT_MESSAGE_TYPE_PUBCOMP, 0, length(varHdr))
   mqttAddArray(varHdr,1,msg,i,length(varHdr)-1)   
}  
#
##################### client to server ###############
# fixed header is always the first n bytes - dependent on
# value of remainingLength, maximum of 4 bytes.
# largest fixed header is 5 bytes
# bits 8-5 are type, 4-1 are flags, byte 2 start remaining length
# flags are only present on publish
# returns number of bytes added to byteArray
function mqttAddFixedHeader(byteArray, msgType, flags, remainingLength,  arr) {
   byteArray[1] = lshift64(msgType,4) + flags
   delete arr
   mqttEncodeMBI(remainingLength, arr)
   mqttAddArray(arr,1,byteArray,2,length(arr)-1)
   # since arrays are indexed from 1, add an additional 1 to gain true offset
   return length(arr)+1+1
}
# build a ping request message in the given array
function mqttBuildPingReq(msg    ) {
    mqttAddFixedHeader(msg, MQTT_MESSAGE_TYPE_PINGREQ, 0, 0)
}
# create a subscribe message
# cfg - configuration array, must contain topic+qos array
#       cfg["subTopics"] = [["topic",qos],...]
function mqttBuildSubscribeMessage(cfg, msg,   i, varHdr, subTopics, topic, j, hex) {
   delete varHdr
   i = 1
   
   #first is the 2 byte packet id. only pubs and subs
   mqttWriteUint16(mqttGetPacketId(),varHdr, i)
   i = i + 2

   # now add the list of topic (string) qos (2bit) pairs
   # in the order presented in the cfg array
   for(j = 1; j <= cfg["subtopicCount"]; j++) {
      mqttWriteUint16(length(cfg["subTopics",j, 1]),varHdr, i)
      i = i + 2
      
      delete hex
      strToIntArray(cfg["subTopics",j, 1],hex,1)
      mqttAddArray(hex,1,varHdr,i,length(hex)-1)
      i = i + length(hex)
      
      varHdr[i++] = and64(cfg["subTopics",j, 2],3)
   }

   i = mqttAddFixedHeader(msg, MQTT_MESSAGE_TYPE_SUBSCRIBE, 2, length(varHdr))
   mqttAddArray(varHdr,1,msg,i,length(varHdr)-1)
}
# create a unsubscribe message
# cfg - configuration array, must contain topic+qos array
#       cfg["subTopics"] = [["topic"],...]
function mqttBuildUnsubscribeMessage(cfg, msg,   i, varHdr, subTopics, topic, j, hex) {
   delete varHdr
   i = 1
   
   #first is the 2 byte packet id. only pubs and subs
   mqttWriteUint16(mqttGetPacketId(),varHdr, i)
   i = i + 2

   # now add the list of topic (string) qos (2bit) pairs
   # in the order presented in the cfg array
   for(j = 1; j <= cfg["subtopicCount"]; j++) {
      mqttWriteUint16(length(cfg["subTopics",j, 1]),varHdr, i)
      i = i + 2
      
      delete hex
      strToIntArray(cfg["subTopics",j, 1],hex,1)
      mqttAddArray(hex,1,varHdr,i,length(hex)-1)
      i = i + length(hex)
   }

   i = mqttAddFixedHeader(msg, MQTT_MESSAGE_TYPE_UNSUBSCRIBE, 2, length(varHdr))
   mqttAddArray(varHdr,1,msg,i,length(varHdr)-1)
}
# create a connect message
# cfg - configuration. expects uname+pass, client id, will, etc.
#       cfg["keepAlive"] required
#       cfg["flags"]     required
#       cfg["clientId"]  required, empty only on clean session
#       cfg["userName"]  optional
#       cfg["password"]  optional
# msg - array to construct message in
# looks like it may be best to leave a message
# in array form - a byte array
function mqttBuildConnectMessage(cfg, msg,    varHdr, hex, i, flags) {   
   flags = cfg["flags"]
   # if zero length client id and clean session not specified
   if(length(cfg["clientId"])<=0 && and64(flags,2) != 2) {
      # specify clean session
      flags = flags + 2;
      print "flags: "flags
   }

   # construct variable header first so we can get remaining length
   delete varHdr
   i = 1
   varHdr[i++] = 0
   varHdr[i++] = 4
   delete hex
   strToIntArray("MQTT",hex,1)
   mqttAddArray(hex,1,varHdr,i,length(hex)-1)
   i = i + length(hex)
   # protocol level
   varHdr[i++] = 4
   # connect flags
   varHdr[i++] = flags
   # keep alive, 2 byte int, in seconds
   mqttWriteUint16(cfg["keepAlive"],varHdr,i)
   i = i + 2
   
   # payload
   # client id - 1st 2 bytes are length, followed by string
   mqttWriteUint16(length(cfg["clientId"]),varHdr,i)
   i = i + 2
   if(length(cfg["clientId"]) > 0) {
      delete hex
      strToIntArray(cfg["clientId"],hex,1)
      mqttAddArray(hex,1,varHdr,i,length(hex)-1)
      i = i + length(hex)
   }
   # will is next, if flag set
   if(and64(flags,4) == 4) {
      # topic first
      mqttWriteUint16(length(cfg["willTopic"]),varHdr,i)
      i = i + 2
      delete hex
      strToIntArray(cfg["willTopic"],hex,1)
      mqttAddArray(hex,1,varHdr,i,length(hex)-1)
      i = i + length(hex)
      # then topic payload
      mqttWriteUint16(length(cfg["willMessage"]),varHdr,i)
      i = i + 2
      if(length(cfg["willMessage"]) > 0) {
         delete hex
         strToIntArray(cfg["willMessage"],hex,1)
         mqttAddArray(hex,1,varHdr,i,length(hex)-1)
         i = i + length(hex)
      }
   }
   # now user name
   if(and64(flags,128) == 128){
      mqttWriteUint16(length(cfg["userName"]),varHdr,i)
      i = i + 2
      if(length(cfg["userName"]) > 0) {
         delete hex
         strToIntArray(cfg["userName"],hex,1)
         mqttAddArray(hex,1,varHdr,i,length(hex)-1)
         i = i + length(hex)
      }
   }
   # finally password
   if(and64(flags,64) == 64){
      mqttWriteUint16(length(cfg["password"]),varHdr,i)
      i = i + 2
      if(length(cfg["password"]) > 0) {
         delete hex
         # this should be binary but we will expect string
         strToIntArray(cfg["password"],hex,1)
         mqttAddArray(hex,1,varHdr,i,length(hex)-1)
         i = i + length(hex)
      }
   }
   #dumpHex(varHdr)
   
   i = mqttAddFixedHeader(msg, MQTT_MESSAGE_TYPE_CONNECT, 0, length(varHdr))
   mqttAddArray(varHdr,1,msg,i,length(varHdr)-1)
}
# build a disconnect message in the given array
function mqttBuildDisconnectMessage(msg    ) {
    mqttAddFixedHeader(msg, MQTT_MESSAGE_TYPE_DISCONNECT, 0, 0)
}
#
##################### connection management #########
function mqttPrimeConnection(    msg, encoded, cmd, cfg) {
   # construct config for connect message
   delete cfg
   # 60 second keepalive
   cfg["keepAlive"] = MQTT_KEEP_ALIVE_INTERVAL
   # prime the flags
   cfg["flags"] = 0
   # set the client id
   cfg["clientId"] = MQTT_CLIENT_ID
   # set the user name
   cfg["flags"] = cfg["flags"] + 128
   cfg["userName"] = MQTT_USERNAME
   # set the password
   cfg["flags"] = cfg["flags"] + 64
   cfg["password"] = MQTT_PASS
   
   delete msg
   mqttBuildConnectMessage(cfg, msg)
   #dumpHex(msg)
   sendHex(msg, 1==1)
}
# Connect to an mqtt endpoint and process messages
#
function mqttConnect(   cmd, result, msg, type, pos, remlen, msginfo, digit, multiplier, decoded, getlength, cfg) {
   # setup for receive
   # pos is the location in the current byte stream
   pos = 0
   # remlen is remaining length of the message
   remlen = 0
   # digit & multiplier are used to construct remaining length for large values
   digit = 128
   multiplier = 1
   # msg is the bytestream
   delete msg
   # follow the state of getting the length
   getlength = 1==0
   # pass message header decoded into config array
   delete cfg
   
   # Client initiates connection by sending a connect message
   # push a connect message into the FIFO then connect
   # this assumes the FIFO is flushed prior to use - may have to extract
   # messages from the FIFO to flush, then add the messages back when the connection is made
   mqttPrimeConnection()
   
   # connect to the endpoint, piping messages from the FIFO
   # into the connection and receiving the results into this function
   cmd = "openssl s_client -quiet -connect "MQTT_ENDPOINT" < "MQTT_INPUT_QUEUE" | ./charrdr.sh"
   while( (cmd | getline result) > 0 ) {
      # since we are using chrrdr.sh, the result variable contains a single character decimal value terminated by newline
	  gsub(/\n/,"",result)
	  
	  # byte array
	  msg[length(msg)+1] = result
	  
	  # get the type and info codes
	  if(pos == 0) {
	     type = rshift64(0+result,4)
         cfg["type"] = type
	     msginfo = and64(0+result,15)
         cfg["flags"] = msginfo
	     pos = pos + 1
	     getlength = 1==1
	     continue
	  }
	  
	  # decode remaining length (MBI format)
	  if(getlength && and64(digit,128) != 0) {
	     digit = 0+result
	     remlen = remlen + (and64(digit,127) * multiplier)	     
         cfg["remainingLength"] = remlen
	     multiplier = multiplier * 128
	     pos = pos + 1
	     continue
	  }
	  getlength = 1==0
	  
	  remlen = remlen - 1
	  
	  # now we can grab the rest of the message
	  # handle the message when all is read in
	  if(remlen <= 0) {
	     #setup for decode
	     delete decoded
	     # since pos is zero based but arrays are indexed 1 based, increment pos on call
         mqttReceiveMessage(cfg,msg,pos+1)
         
         # setup for receive
	     pos = 0
	     remlen = 0
	     digit = 128
	     multiplier = 1
	     delete msg
         delete cfg
      }
   }
   
	#close command
	close(cmd)
}
#
# get packet identifier
# TODO we should queue a message under its id for
#      purpose of ack coordination and retransmission per protocol
function mqttGetPacketId(   i) {
   # keep track of the used packet ids
   # allow retire of packet id on ack
   # packet ids are 2 bytes, max 65534
   # this is inefficient but we don't have hastable
   if(length(MQTT_PACKET_IDS) <= 0) {
       delete MQTT_PACKET_IDS
       MQTT_PACKET_IDS[1] = "allocated"
       return 1
   }
   for(i=1; i <= length(MQTT_PACKET_IDS); i++) {
       if(MQTT_PACKET_IDS[i] == "open" ){
           # open slot
           MQTT_PACKET_IDS[i] = "allocated"
           return i
       }
   }
   i = length(MQTT_PACKET_IDS)+1
   MQTT_PACKET_IDS[i] = "allocated"
   return i
}
# release the packet id so it can be reused
function mqttReleasePacketId(id) {
   # keep track of the used packet ids
   # allow retire of packet id on ack
   # packet ids are 2 bytes, max 65534
   # this is inefficient but we don't have hastable
   if(length(MQTT_PACKET_IDS) <= 0) {
       delete MQTT_PACKET_IDS
   }
   MQTT_PACKET_IDS[id] = "open"
   return
}
#
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
#################### server to client ##############
# handle receipt of a connection acknowledgement
# cfg current set of message configuration values
# varHdr message starting with variable header and continuing through payload
function mqttHandleConnAck(cfg, varHdr,   returnCode) {
   SESSION_PRESENT = and64(varHdr[1],1)
   returnCode = varHdr[2]
   CONNECTED = (1==0)
   if(returnCode == 0) {
      print "connection accepted"
      CONNECTED = (1==1)
   } else if(returnCode == 1 ) {
      print "bad proto version"
   } else if(returnCode == 2 ) {
      print "id rejected"
   } else if(returnCode == 3 ) {
      print "service unavailable"
   } else if(returnCode == 4 ) {
      print "bad user or password"
   } else if(returnCode == 5 ) {
      print "not authorized"
   }
}
# receive a publish message
# will decode into cfg additional values, then will call handler
# to receive the payload and topic. then will ack accordingly
# cfg - configuration decoded so far
# varHdr - remaining message
function mqttReceivePublish(cfg, varHdr,   pos, len, msg) {
   cfg["dup"] = and64(rshift64(cfg["flags"],3),1)
   cfg["qos"] = and64(rshift64(cfg["flags"],1),3)
   cfg["retain"] = and64(cfg["flags"],1)
   
   pos = 1
   # topic name
   len = mqttReadUint16(varHdr, pos)
   pos = pos + 2
   cfg["topic"] = intArrayToStr(varHdr, pos, len)
   pos = pos + len
   
   # packet identifier
   cfg["packetid"] = mqttReadUint16(varHdr, pos)
   pos = pos + 2
   
   # and the rest is payload - calculate its length
   len = cfg["remainingLength"] - (len + 4)
   
   # TODO deliver the message
   
   # acknowledge
   delete msg
   if(cfg["qos"] == 1) {
      mqttBuildPubAckMessage(cfg["packetid"], msg)
   } else if(cfg["qos"] == 2) {
      mqttBuildPubRecMessage(cfg["packetid"], msg)
   }
   # else no response required
   if(length(msg) > 0) {
      # send the acknowledgement
      sendHex(msg, 1==1)
   }
}
# receive a publish acknowledgement 
# cfg - configuration parsed so far
# varHdr - remaining message
function mqttReceivePubAck(cfg, varHdr,    pos) {
   pos = 1
   # packet identifier
   cfg["packetid"] = mqttReadUint16(varHdr, pos)
   pos = pos + 2
   
   # release the packet identifier
   mqttReleasePacketId(cfg["packetid"])
}
# receive a publish received message 
# cfg - configuration parsed so far
# varHdr - remaining message
function mqttReceivePubRec(cfg, varHdr,    pos, msg) {
   pos = 1
   # packet identifier
   cfg["packetid"] = mqttReadUint16(varHdr, pos)
   pos = pos + 2
   
   # TODO send pub release message
   delete msg
   mqttBuildPubRelMessage(cfg["packetid"],msg)
   sendHex(msg, 1==1)
}
# receive a publish release message 
# cfg - configuration parsed so far
# varHdr - remaining message
function mqttReceivePubRel(cfg, varHdr,    pos, msg) {
   pos = 1
   # packet identifier
   cfg["packetid"] = mqttReadUint16(varHdr, pos)
   pos = pos + 2
   
   # TODO send pub comp message
   delete msg
   mqttBuildPubCompMessage(cfg["packetid"],msg)
   sendHex(msg, 1==1)
}
# receive a publish acknowledgement 
# cfg - configuration parsed so far
# varHdr - remaining message
function mqttReceivePubComp(cfg, varHdr,    pos) {
   pos = 1
   # packet identifier
   cfg["packetid"] = mqttReadUint16(varHdr, pos)
   pos = pos + 2
   
   # release the packet identifier
   mqttReleasePacketId(cfg["packetid"])
}
# receive a subscribe acknowledgement 
# cfg - configuration parsed so far
# varHdr - remaining message
function mqttReceiveSubAck(cfg, varHdr,    pos) {
   pos = 1
   # packet identifier
   cfg["packetid"] = mqttReadUint16(varHdr, pos)
   pos = pos + 2
   
   #TODO report qos and failure
   # x80 failure, 0 1 and 2 - success for qos 
   # codes returned in order they were requested
   
   # release the packet identifier
   mqttReleasePacketId(cfg["packetid"])
}
# receive a unsubscribe acknowledgement 
# cfg - configuration parsed so far
# varHdr - remaining message
function mqttReceiveUnsubAck(cfg, varHdr,    pos) {
   pos = 1
   # packet identifier
   cfg["packetid"] = mqttReadUint16(varHdr, pos)
   pos = pos + 2
   
   # release the packet identifier
   mqttReleasePacketId(cfg["packetid"])
}
# receive the message from the server
function mqttReceiveMessage(cfg,msg,offset,   varHdr) {
    delete varHdr
    mqttAddArray(msg,offset,varHdr,1,length(msg)-offset)
    
    if(cfg["type"] == MQTT_MESSAGE_TYPE_CONNACK) {
       mqttHandleConnAck(cfg, varHdr)
    }
    else if(cfg["type"] == MQTT_MESSAGE_TYPE_PUBLISH) {
       mqttReceivePublish(cfg, varHdr)
    }
    else if(cfg["type"] == MQTT_MESSAGE_TYPE_PUBACK) {
       mqttReceivePubAck(cfg, varHdr)
    }
    else if(cfg["type"] == MQTT_MESSAGE_TYPE_PUBREC) {
       mqttReceivePubRec(cfg, varHdr)
    }
    else if(cfg["type"] == MQTT_MESSAGE_TYPE_PUBREL) {
       mqttReceivePubRel(cfg, varHdr)
    }
    else if(cfg["type"] == MQTT_MESSAGE_TYPE_PUBCOMP) {
       mqttReceivePubComp(cfg, varHdr)
    }
    else if(cfg["type"] == MQTT_MESSAGE_TYPE_SUBACK) {
       mqttReceiveSubAck(cfg, varHdr)
    }
    else if(cfg["type"] == MQTT_MESSAGE_TYPE_UNSUBACK) {
       mqttReceiveUnsubAck(cfg, varHdr)
    }
    else if(cfg["type"] == MQTT_MESSAGE_TYPE_PINGRESP) {
       #TODO this indicates connection still present
    }
    else if(cfg["type"] == MQTT_MESSAGE_TYPE_DISCONNECT) {
       # this should not be received as it is a client->server message
       print "Error received disconnect"
    }
    else {
       print "Error invalid mqtt message type"
    }
}
#
################ entry ######################
BEGIN {
   mqttSetup()
   if(ARGC > 1) {
      # if called with arguments
      processCmdLine()
   }
}
#