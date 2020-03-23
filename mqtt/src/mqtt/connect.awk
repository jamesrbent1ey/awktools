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
