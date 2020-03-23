################ entry ######################
BEGIN {
   mqttSetup()
   if(ARGC > 1) {
      # if called with arguments
      processCmdLine()
   }
}
#