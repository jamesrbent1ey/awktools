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
