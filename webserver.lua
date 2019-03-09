-- webserver.lua
--webserver sample from the nodemcu github
print(wifi.sta.getip())
sntp.sync(nil,nil,function() print("sntp failed") end,nil)
if srv~=nil then
 srv:close()
end

gpio.mode(1, gpio.OUTPUT)

swhour=""
swmin=""

swhouroff=""
swminoff=""

function tryonofftime(hv, mv, sv, onoff)
    tm = rtctime.epoch2cal(rtctime.get()+32400)
    hs = tm["hour"]
    ms = tm["min"]
    ss = tm["sec"]
    setflag=false
    if hv~="" or mv~="" then
        if hv=="" or (hv~="" and hs==tonumber(hv)) then
          if mv=="" or (mv~="" and ms==tonumber(mv)) then
            if sv=="" or (sv~="" and ss>=tonumber(sv)) then
              setflag=true
            end
          end
        end
        if onoff~=nil and setflag then
          gpio.write(1, onoff)
        end
    end
    return setflag
end

function tmrout(s)
  if s~="" then
    return s
  else
    return "**"
  end
end

srv=net.createServer(net.TCP)
srv:listen(80,function(conn)
    conn:on("receive", function(client,request)
        local buf = ""
        local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP")
        if(method == nil)then
            _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP")
        end
        local _GET = {}
        if (vars ~= nil)then
            for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do
                _GET[k] = v
            end
        end
        tm = rtctime.epoch2cal(rtctime.get()+32400)
        buf = buf..string.format("<h1>%04d/%02d/%02d %02d:%02d:%02d</h1>", tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"])
        buf = buf.."<h1> Set relay</h1><form id=form1 src=\"/\">Turn PIN1 <select name=\"pin\" onchange=\"form.submit()\">"
        local _on,_off = "",""
        if(_GET.pin == "ON")then
              tmr.stop(1)
              _on = " selected=true"              
              gpio.write(1, gpio.HIGH)
        elseif(_GET.pin == "OFF")then
              tmr.stop(1)
              _off = " selected=true"
              gpio.write(1, gpio.LOW)
        else
          if gpio.read(1)==1 then
            _on = " selected=true"
          else
            _off = " selected=true"
          end
        end
        -- hour, min
        if _GET.swpin~=nil then
            if _GET.swpin=="ON" then
                if _GET.hour~=nil then
                  swhour=_GET.hour
                else
                  swhour=""
                end
                if _GET.min~=nil then
                  swmin=_GET.min
                else
                  swmin=""
                end
            else 
                if _GET.hour~=nil then
                  swhouroff=_GET.hour
                else
                  swhouroff=""
                end
                if _GET.min~=nil then
                  swminoff=_GET.min
                else
                  swminoff=""
                end
            end
        end
        if swhour~="" or swmin~="" or swhouroff~="" or swminoff~="" then
          tmr.alarm(1, 1000, tmr.ALARM_AUTO, function()
            tryonofftime(swhour, swmin, "", gpio.HIGH)
            tryonofftime(swhouroff, swminoff, "", gpio.LOW)
          end)
        else
          tmr.stop(1)
        end
        buf = buf.."<option".._on..">ON</opton><option".._off..">OFF</option></select></form>"
        -- on timer
        buf = buf.."<form id=form2 src=\"/\">On/Off Time<select name=\"hour\"><option"
        if swhour=="" then
          buf = buf.." selected=true"
        end
        buf = buf.."></option>"
        for timehour=0,23 do
          buf = buf.."<option"
          if swhour~="" and timehour==tonumber(swhour) then
            buf=buf.." selected=true"
          end
          buf=buf..">"..tostring(timehour).."</option>"
        end
        buf = buf.."</select>:<select name=\"min\"><option"
        if swmin=="" then
          buf = buf.." selected=true"
        end
        buf = buf.."></option>"
        for timemin=0,59 do
          buf = buf.."<option"
          if swmin~="" and timemin==tonumber(swmin) then
            buf=buf.." selected=true"
          end
          buf=buf..">"..tostring(timemin).."</option>"
        end
        _swon=""
        _swoff=""
        if swhour~="" or swmin~="" then
          _swoff = " selected=true"
        else
          _swon = " selected=true"
        end        
        buf = buf.."</select><select name=swpin><option".._swon..">ON</option><option".._swoff..">OFF</option>"
        buf = buf.."</select><button type=submit>Set</button></form>"        
        buf = buf..string.format("%2s:%2s (on) <br/> %2s:%2s (off)",tmrout(swhour),tmrout(swmin),tmrout(swhouroff),tmrout(swminoff))
        client:send(buf)
    end)
    conn:on("sent", function (c) c:close() end)
end)
