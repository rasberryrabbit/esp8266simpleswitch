-- webserver.lua
--webserver sample from the nodemcu github

if wifi.getmode() == wifi.SOFTAP then
  webip=wifi.ap.getip()
  broadip=wifi.ap.getbroadcast()
else
  webip=wifi.sta.getip()
  broadip=wifi.sta.getbroadcast()
end

print(webip)

function synctime()
  sntp.sync(nil,nil,function() print("sntp failed") end,nil)
end

pcall(synctime)

if srv~=nil then
 srv:close()
end

gpio.mode(1, gpio.OUTPUT)

config = "setting.txt"
onshotload = false

autoload=""
swhour=""
swmin=""

swhouroff=""
swminoff=""
timeractive=0
dotimer=0
offsettime=32400

tmrcheck=tmr.create()

function tryonofftime(hv, mv, sv, onoff)
    tm = rtctime.epoch2cal(rtctime.get()+offsettime)
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
          gpio.write(4, 1-onoff)
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

function toint(s)
  return tonumber(s)
end

function checknil(s)
  if s==nil then
    return ""
  else
    return string.gsub(s, "%s+", "")
  end
end

function load_setting()
  if oneshotload~=true then
    oneshotload=true
  if file.exists(config) then
    fc = file.open(config,"r")
    autoload=checknil(fc:readline())
    swhour=checknil(fc:readline())
    swmin=checknil(fc:readline())
    swhouroff=checknil(fc:readline())
    swminoff=checknil(fc:readline())
    fc:close()
    -- start timer
    if string.find(autoload,"YES") then
      tmrcheck.unregister()
      tmrcheck:register(1000, tmr.ALARM_AUTO, function()
        tryonofftime(swhour, swmin, "", gpio.HIGH)
        tryonofftime(swhouroff, swminoff, "", gpio.LOW)
      end)
      timeractive=1
      tmrcheck:start()
    end
  end
  end
end

function save_setting()
  fc = file.open(config,"w")
  fc:writeline(autoload)
  fc:writeline(swhour)
  fc:writeline(swmin)
  fc:writeline(swhouroff)
  fc:writeline(swminoff) 
  fc:close()
end

function remove_setting()
  file.remove(config)
end

srv=net.createServer(net.TCP)
srv:listen(80,function(conn)
    conn:on("receive", function(client,request)
        local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP")
        if(method == nil)then
            _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP")
        end
        -- ignore favicon request
        if path=="/favicon.ico" then
          return
        end
        local _GET = {}
        if (vars ~= nil)then
            for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do
                _GET[k] = v
            end
        end
        vars=nil
        tm = rtctime.epoch2cal(rtctime.get()+offsettime)
        buf={}
        buf[#buf+1] = string.format("<html><body><h3>%04d/%02d/%02d %02d:%02d:%02d</h3>", tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"])
        buf[#buf+1] = "<h3> Set relay</h3><form id=form1 src=\"/\">Turn PIN1 <select name=\"pin\" onchange=\"form.submit()\">"
        local _on,_off = "",""
        if(_GET.pin == "ON")then
              _on = " selected=true"              
              gpio.write(1, gpio.HIGH)
              gpio.write(4, gpio.LOW)
              tmrcheck:stop()
              timeractive=0
        elseif(_GET.pin == "OFF")then
              _off = " selected=true"
              gpio.write(1, gpio.LOW)
              gpio.write(4, gpio.HIGH)
              tmrcheck:stop()
              timeractive=0
        else
          if gpio.read(1)==1 then
            _on = " selected=\"selected\""
          else
            _off = " selected=\"selected\""
          end
        end
        -- delete setting.txt
        if _GET.delete~=nil then
          if _GET.delete=="YES" then
            if pcall(remove_setting)~=true then
              print("fail remove setting")
            end
          end
        end
        -- hour, min
        local newhour=nil
        local newmin=nil
        if _GET.swpin~=nil then
            autoload=checknil(_GET.autoload)
            if _GET.hour~=nil then
              newhour=_GET.hour
              local y, x = pcall(toint,newhour)
              if y==true then
                if x>=24 then
                  newhour="23"
                end
              else
                newhour=""
              end
            else
              newhour=""
            end
            if _GET.min~=nil then
              newmin=_GET.min
              local y,x = pcall(toint,newmin)
              if y==true then
                if x>=60 then
                  newmin="59"
                end
              else
                newmin=""
              end
            else
              newmin=""
            end
            if _GET.swpin=="ON" then
                swhour=newhour
                swmin=newmin
            else
                swhouroff=newhour
                swminoff=newmin
            end
            -- save config
            if _GET.dosave=="YES" then
              if pcall(save_setting)==false then
                print("fail save config")
              end
            end
        else
            -- one shot load
            pcall(load_setting)
        end
        -- start timer
        if _GET.hour~=nil or _GET.min~=nil then
          tmrcheck:stop()
          if newhour~="" or newmin~="" then
              tmrcheck:unregister()
              tmrcheck:register(1000, tmr.ALARM_AUTO, function()
                tryonofftime(swhour, swmin, "", gpio.HIGH)
                tryonofftime(swhouroff, swminoff, "", gpio.LOW)
              end)
              timeractive=1
              tmrcheck:start()
          else
              timeractive=0
          end
        end
        buf[#buf+1] = "<option".._on..">ON</opton><option".._off..">OFF</option></select></form>"
        -- on timer
        buf[#buf+1] = "<p>Timer : "
        if timeractive==0 then
          buf[#buf+1] = "disabled"
        else
          buf[#buf+1] = "enabled"
        end
        local texthour=""
        local textmin=""
        if swhour~="" then
          texthour=swhour
        else
          texthour=swhouroff
        end
        if swmin~="" then
          textmin=swmin
        else
          textmin=swminoff
        end
        buf[#buf+1] = "</p>"
        buf[#buf+1] = "<form id=form2 src=\"/\">On/Off Time<input type=\"text\" name=\"hour\" value=\""..texthour.."\" size=3>"
        buf[#buf+1] = ":<input type=\"text\" name=\"min\" value=\""..textmin.."\" size=3>"
        _swon=""
        _swoff=""
        if swhour~="" or swmin~="" then
          _swoff = " selected=true"
        else
          _swon = " selected=true"
        end        
        buf[#buf+1] = "<select name=swpin><option".._swon..">ON</option><option".._swoff..">OFF</option></select>"
        autoloadflag=""
        if string.find(autoload,"YES")~=nil then
          autoloadflag = "checked"
        end
        buf[#buf+1] = "<br/><br/><input type=\"checkbox\" name=\"autoload\" value=\"YES\" "..autoloadflag..">Auto loading<br/>"
        buf[#buf+1] = "<input type=\"checkbox\" name=\"dosave\" value=\"YES\">Save config<br/><br/><button type=submit>Set</button></form>"
        buf[#buf+1] = "<form id=form3 src=\"/\"><input type=\"hidden\" name=\"pin\" value=\"OFF\"><input type=\"hidden\" name=\"hour\" value=\"\">"
        buf[#buf+1] = "<input type=\"hidden\" name=\"min\" value=\"\"><button type=submit>Turn off Reset</button></form>"
        buf[#buf+1] = "<form id=form4 src=\"/\"><input type=\"hidden\" name=\"delete\" value=\"YES\"><button type=submit>Delete setting</button></form>"
        buf[#buf+1] = string.format("%2s:%2s (on) <br/> %2s:%2s (off)",tmrout(swhour),tmrout(swmin),tmrout(swhouroff),tmrout(swminoff))
        buf[#buf+1] = "</body></html>"
        conn:send(table.remove(buf,1))
    end)
    conn:on("sent", function (c) 
      if #buf > 0 then
        conn:send(table.remove(buf,1))
      else
        c:close()
      end
    end)
end)

local udpmsg=webip.."\n"..string.format("%x",node.chipid()).."\nSWITCH-INFO\npin[ON|OFF],hour[24],min[60],swpin[ON|OFF]\n"
udp50k = net.createUDPSocket()
udptmr=tmr.create()
udptmr:register(3000, tmr.ALARM_AUTO, function()
  udp50k:send(50000, broadip, udpmsg)
end)
udptmr:start()

