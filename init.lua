-- init.lua
pin = 5 --Reset PIN
Resetta=0   --Variable used to manage AP reset
gpio.mode(pin,gpio.INPUT)   --Pin 5 in input mode

--If pin input is High let's start the nodemcu portal
if (gpio.read(pin)==gpio.LOW) then 

    Resetta=1
end

starttmr=tmr.create()
starttmr:register(3000, tmr.ALARM_SINGLE, function()
    if file.list()["webserver.lua"] then
        dofile("webserver.lua")
    end
end)

-- Check if reset the AP credential
if Resetta==1 then 
    -- Start the nodemcu portal
    local aptimer=tmr.create()
    aptimer:register(5000,tmr.ALARM_SINGLE, function()
      if file.list()["riazzerawifi.lua"] then
        dofile("riazzerawifi.lua")
      end
    end)
    aptimer:start()

else
    cnt = 30
    wbtimer=tmr.create()
    wbtimer:register(1000, tmr.ALARM_AUTO, function()
      if wifi.sta.getip()==nil then
        cnt = cnt - 1
        if cnt==0 then
          gpio.mode(4,gpio.OUTPUT)
          iptimer:register(500, tmr.ALARM_SINGLE, function()
            gpio.write(4,1-gpio.read(4))
          end)
          gpio.write(4,1-gpio.read(4))
          iptimer:start()

          print("Cannot get IP")
          wifi.sta.disconnect()
          wifi.setmode(wifi.SOFTAP)
          --ESP SSID generated wiht its chipid
          wifi.ap.config({ssid="Switch-"..node.chipid()
          , auth=wifi.OPEN})
          print(wifi.ap.getip())
        end
      else
        wbtimer:unregister()
        starttmr:start()
      end
    end)
    wbtimer:start()
end
