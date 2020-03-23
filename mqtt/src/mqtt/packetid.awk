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
