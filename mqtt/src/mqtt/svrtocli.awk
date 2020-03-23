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
