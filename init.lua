-- init.lua
--Access Point management
-- this code from http://www.microdev.it/wp/en/2016/11/28/nodemcu-enduser_setup-module-lua-samplepart2/
pin = 5 --Input PIN
Resetta=0   --Variable used to manage AP reset
gpio.mode(pin,gpio.INPUT)   --Pin 5 in input mode

--If pin input is High let's start the nodemcu portal
if (gpio.read(pin)==gpio.LOW) then 

    Resetta=1
end

-- Check if reset the AP credential
if Resetta==1 then 
    -- Start the nodemcu portal
    tmr.alarm(0, 5000, 0, function() dofile("riazzerawifi.lua") end)

else
    cnt = 10
    tmr.alarm(0, 1000, 1, function()
      if wifi.sta.getip()==nil then
        cnt = cnt - 1
        if cnt==0 then
          tmr.stop(0)
          gpio.mode(4,gpio.OUTPUT)
          tmr.alarm(0, 500, 1, function()
            gpio.write(4,1-gpio.read(4))
          end)
          print("Cannot get IP")
        end
      else
        tmr.stop(0)
        -- Start the webserver wiht ip defined by Wi-Fi router
        tmr.alarm(0, 5000, 0, function() dofile("webserver.lua") end)
      end
    end)

end
