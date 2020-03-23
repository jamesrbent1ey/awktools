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
