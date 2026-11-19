local http = luci.http
local nixio = require "nixio"

m = Map("vnt")
m.description = translate('vnt是一个简便高效的异地组网、内网穿透工具。')

-- vnt-cli
m:section(SimpleSection).template  = "vnt/vnt_status"

s = m:section(TypedSection, "vnt-cli", translate("vnt-cli 客户端设置"))
s.anonymous = true

s:tab("general", translate("基本设置"))
s:tab("privacy", translate("高级设置"))
s:tab("infos", translate("连接信息"))
s:tab("upload", translate("上传程序"))

switch = s:taboption("general",Flag, "enabled", translate("Enable"))
switch.rmempty = false

btncq = s:taboption("general", Button, "btncq", translate("重启"))
btncq.inputtitle = translate("重启")
btncq.description = translate("在没有修改参数的情况下快速重新启动一次")
btncq.inputstyle = "apply"
btncq:depends("enabled", "1")
btncq.write = function()
  os.execute("/etc/init.d/vnt restart ")
end

token = s:taboption("general", Value, "token", translate("Token"),
	translate("这是必填项！一个虚拟局域网的标识，连接同一服务器时，使用相同token的客户端设备才会组成一个局域网（这是 -k 参数）"))
token.optional = false
token.password = true
token.placeholder = "test"
token.datatype = "string"
token.maxlength = 63
token.minlength = 1
token.validate = function(self, value, section)
    if value and #value >= 1 and #value <= 63 then
        return value
    else
        return nil, translate("Token为必填项，可填1至63位字符")
    end
end
switch.write = function(self, section, value)
    if value == "1" then
        token.rmempty = false
    else
        token.rmempty = true
    end
    return Flag.write(self, section, value)
end

mode = s:taboption("general",ListValue, "mode", translate("接口模式"),
	translate("动态分配将由服务器随机分配一个未使用的ip地址，重启程序可能导致ip变化，建议手动指定ip并指定设备ID"))
mode:value("dhcp",translate("动态分配"))
mode:value("static",translate("手动指定"))

ipaddr = s:taboption("general",Value, "ipaddr", translate("接口IP地址"),
	translate("每个vnt-cli客户端的接口IP不能相同"))
ipaddr.optional = false
ipaddr.datatype = "ip4addr"
ipaddr.placeholder = "10.26.0.5"
ipaddr:depends("mode", "static")

desvice_id = s:taboption("general",Value, "desvice_id", translate("设备ID"),
	translate("每台设备的唯一标识，注意不要重复，每个vnt-cli客户端的设备ID不能相同"))
desvice_id.placeholder = "5"

localadd = s:taboption("general",DynamicList, "localadd", translate("本地网段"),
	translate("每个vnt-cli客户端的内网lan网段不能相同，例如本机lanIP为192.168.1.1则填 192.168.1.0/24 "))
localadd.placeholder = "192.168.1.0/24"

peeradd = s:taboption("general",DynamicList, "peeradd", translate("对端网段"),
	translate("格式为对端的lanIP网段加英文，对端的接口IP，例如对端lanIP为192.168.2.1接口IP10.26.0.3则填192.168.2.0/24,10.26.0.3"))
peeradd.placeholder = "192.168.2.0/24,10.26.0.3"

forward = s:taboption("general",Flag, "forward", translate("启用IP转发"),
	translate("内置的IP代理较为简单，而且一般来说直接使用网卡NAT转发性能会更高,所以默认开启IP转发关闭内置的ip代理"))
forward.rmempty = false

allow_wg = s:taboption("general",Flag, "allow_wg", translate("允许WireGuard接入"),
	translate("由于WireGuard是来自vnts转发的，如果vnts不受信任，这将会有安全隐患，所以默认不允许WireGuard流量访问本机"))
allow_wg.rmempty = false

log = s:taboption("general",Flag, "log", translate("启用日志"),
	translate("运行日志在/tmp/vnt.log,可在上方客户端日志查看"))
log.rmempty = false

clibin = s:taboption("privacy", Value, "clibin", translate("vnt-cli程序路径"),
	translate("自定义vnt-cli的存放路径，确保填写完整的路径及名称,若指定的路径可用空间不足将会自动移至/tmp/vnt-cli"))
clibin.placeholder = "/usr/bin/vnt-cli"

vntshost = s:taboption("privacy", Value, "vntshost", translate("vnts服务器地址"),
	translate("相同的服务器，相同token的设备才会组成一个局域网<br>协议支持使用tcp://和ws://和wss://,默认为udp://"))
vntshost.placeholder = "tcp://域名:端口"

vntdns = s:taboption("privacy",DynamicList, "vntdns", translate("DNS服务器"),
	translate("指定DNS服务器地址,可使用多个dns,不指定时使用系统解析"))
vntdns.placeholder = "8.8.8.8:53"

stunhost = s:taboption("privacy",DynamicList, "stunhost", translate("stun服务器地址"),
	translate("使用stun服务探测客户端NAT类型，不同类型有不同的打洞策略，最多三个，超过将被忽略<br>已内置谷歌 QQ 可不填，一些<a href='https://github.com/heiher/natmap/issues/18#issue-1580804352' target='_blank'>免费stun服务器</a>"))
stunhost.placeholder = "stun.qq.com:3478"

local model = nixio.fs.readfile("/proc/device-tree/model") or ""
local hostname = nixio.fs.readfile("/proc/sys/kernel/hostname") or ""
model = model:gsub("\n", "")
hostname = hostname:gsub("\n", "")
local device_name = (model ~= "" and model) or (hostname ~= "" and hostname) or "OpenWrt"
device_name = device_name:gsub(" ", "_")
desvice_name = s:taboption("privacy", Value, "desvice_name", translate("设备名称"),
    translate("本机设备名称，方便区分不同设备"))
desvice_name.placeholder = device_name
desvice_name.default = device_name

tunname = s:taboption("privacy",Value, "tunname", translate("虚拟网卡名称"),
	translate("自定义虚拟网卡的名称，在多开时虚拟网卡名称不能相同，默认为 vnt-tun"))
tunname.placeholder = "vnt-tun"

relay = s:taboption("privacy",ListValue, "relay", translate("传输模式"),
	translate("自动:根据当前网络环境，自动选择由服务器或客户端转发还是客户端之间直连<br>转发:仅中继转发，会禁止打洞/p2p直连，只使用服务器或客户端转发<br>p2p:仅直连模式，会禁止网络数据从服务器/客户端转发，只会使用服务器转发控制包<br>在网络环境很差时，不使用p2p只使用服务器中继转发效果可能更好（可以配合服务器的tcp协议一起使用）<br>tcp直连需要指定监听port，且防火墙需要放行第一个端口，才有几率tcp-p2p"))
relay:value("自动")
relay:value("转发")
relay:value("P2P")

client_port = s:taboption("privacy", Value, "client_port", translate("本地监听端口"),
	translate("取值0~65535，指定本地监听的端口组，多个端口使用英文逗号分隔,多个端口可以分摊流量，增加并发，tcp会监听端口组的第一个端口，用于tcp直连<br>例1：12345,12346,12347 表示udp监听12345、12346、12347这三个端口，tcp监听12345端口<br>例2：0,0 表示udp监听两个未使用的端口，tcp监听一个未使用的端口"))
client_port.placeholder = "0,0"

mapping = s:taboption("privacy",DynamicList, "mapping", translate("端口映射"),
	translate("端口映射,可以设置多个映射地址，例如 udp:0.0.0.0:80-10.26.0.10:80 和 tcp:0.0.0.0:80-10.26.0.11:81 <br>表示将本地udp 80端口的数据转发到10.26.0.10:80，将本地tcp 80端口的数据转发到10.26.0.11:81，转发的目的地址可以使用域名+端口"))
mapping.placeholder = "tcp:0.0.0.0:80-10.26.0.10:80"

mtu = s:taboption("privacy",Value, "mtu", translate("MTU"),
	translate("设置虚拟网卡的mtu值，大多数情况下（留空）使用默认值效率会更高，也可根据实际情况进行微调，默认值：不加密1450，加密1410"))
mtu.datatype = "range(1,1500)"
mtu.placeholder = "1300"

punch = s:taboption("privacy",ListValue, "punch", translate("打洞模式"),
	translate("选择只使用ipv4打洞或者只使用ipv6打洞，all都会使用,ipv6相对于ipv4速率可能会有所降低，ipv6更容易打通直连"))
punch:value("all",translate("都使用"))
punch:value("ipv4",translate("仅ipv4-tcp/udp"))
punch:value("ipv6",translate("仅ipv6-tcp/udp"))
punch:value("ipv4-tcp",translate("仅ipv4-tcp"))
punch:value("ipv6-tcp",translate("仅ipv6-tcp"))
punch:value("ipv4-udp",translate("仅ipv4-udp"))
punch:value("ipv6-udp",translate("仅ipv6-udp"))

comp = s:taboption("privacy",ListValue, "comp", translate("启用压缩"),
	translate("启用压缩，默认仅支持lz4压缩，开启压缩后，如果数据包长度大于等于128，则会使用压缩，否则还是会按原数据发送<br>也支持zstd压缩，但是需要确认程序编译时是否添加支持zstd否则无法启动！编译参数--features zstd<br>如果宽度速度比较慢，可以考虑使用高级别的压缩"))
comp:value("OFF",translate("关闭"))
comp:value("lz4")
comp:value("zstd")

passmode = s:taboption("privacy",ListValue, "passmode", translate("加密模式"),
	translate("默认off不加密，通常情况aes_gcm安全性高、aes_ecb性能更好，在低性能设备上aes_ecb、chacha20、chacha20_poly1305、xor速度最快<br>注意：xor为数据混淆，并不是一种强大的加密算法，易被破解，因此不适合用于真正的加密需求"))
passmode:value("off",translate("不加密"))
passmode:value("aes_ecb")
passmode:value("sm4_cbc")
passmode:value("aes_cbc")
passmode:value("aes_gcm")
passmode:value("chacha20")
passmode:value("chacha20_poly1305")
passmode:value("xor")

key = s:taboption("privacy",Value, "key", translate("加密密钥"),
	translate("先开启上方的加密模式再填写密钥才能生效，使用相同密钥的客户端才能通信，服务端无法解密(包括中继转发数据)"))
key.placeholder = "wodemima"
key.password = true
key:depends("passmode", "aes_ecb")
key:depends("passmode", "sm4_cbc")
key:depends("passmode", "sm4_cbc")
key:depends("passmode", "aes_gcm")
key:depends("passmode", "chacha20")
key:depends("passmode", "chacha20_poly1305")
key:depends("passmode", "xor")

local sys = require("luci.sys")

local_dev = s:taboption("privacy", ListValue, "local_dev", translate("绑定出口网卡"),
    translate("指定作为流量出口的网卡"))
local_dev.optional = false

-- 添加空白值作为默认选项
local_dev:value("", translate("不绑定"))

-- 获取通过 ifconfig 列出的网卡接口
local ifaces = sys.exec("ifconfig | grep -E '^[a-zA-Z0-9]+' | awk -F':' '{print $1}' | awk '{print $1}'")
for iface in string.gmatch(ifaces, "%S+") do
    -- 使用 ip 命令获取网卡的 IP 地址
    local ip_addr = sys.exec("ifconfig " .. iface .. " | grep 'inet ' | awk '{print $2}'")
    ip_addr = ip_addr:gsub("%s+", "")  -- 去除回车和空白字符
    
    -- 如果没有找到 IP 地址，则继续下一个网卡
    if ip_addr ~= "" then
        -- 将网卡名作为值，IP地址作为显示名称
        local_dev:value(iface, iface .. " (" .. ip_addr .. ")")
    end
end

serverw = s:taboption("privacy",Flag, "serverw", translate("启用服务端客户端加密"),
	translate("用服务端通信的数据加密，采用rsa+aes256gcm加密客户端和服务端之间通信的数据，可以避免token泄漏、中间人攻击，<br>上面的加密模式是客户端与客户端之间加密，这是服务器和客户端之间的加密，不是一个性质，无需选择加密模式"))
serverw.rmempty = false

finger = s:taboption("privacy",Flag, "finger", translate("启用数据指纹校验"),
	translate("开启数据指纹校验，可增加安全性，如果服务端开启指纹校验，则客户端也必须开启，开启会损耗一部分性能。<br>注意：默认情况下服务端不会对中转的数据做校验，如果要对中转的数据做校验，则需要客户端、服务端都开启此参数"))
finger.rmempty = false

first_latency = s:taboption("privacy",Flag, "first_latency", translate("启用优化传输"),
	translate("启用后优先使用低延迟通道，默认情况下优先使用p2p通道，某些情况下可能p2p比客户端中继延迟更高，可启用此参数进行优化传输"))
first_latency.rmempty = false

disable_stats = s:taboption("privacy",Flag, "disable_stats", translate("启用流量统计"),
	translate("记录vnt使用的流量统计信息"))
disable_stats.rmempty = false

vnt_forward = s:taboption("privacy",MultiValue, "vnt_forward", translate("访问控制"),
	translate("设置不同网络区域之间的流量允许规则"))
vnt_forward:value("vntfwlan", translate("允许从虚拟网络 VNT 到局域网 lan 的流量"))
vnt_forward:value("vntfwwan", translate("允许从虚拟网络 VNT 到广域网 wan 的流量"))
vnt_forward:value("lanfwvnt", translate("允许从局域网 lan 到虚拟网络 VNT 的流量"))
vnt_forward:value("wanfwvnt", translate("允许从广域网 wan 到虚拟网络 VNT 的流量"))
vnt_forward.default = "vntfwlan vntfwwan lanfwvnt"
vnt_forward.rmempty = true

check = s:taboption("privacy",Flag, "check", translate("通断检测"),
        translate("开启通断检测后，可以指定对端的设备IP，当所有指定的IP都ping不通时将会重启vnt程序"))

checkip=s:taboption("privacy",DynamicList,"checkip",translate("检测IP"),
        translate("确保这里的对端设备IP地址填写正确且可访问，若填写错误将会导致无法ping通，程序反复重启"))
checkip.rmempty = true
checkip.datatype = "ip4addr"
checkip:depends("check", "1")

checktime = s:taboption("privacy",ListValue, "checktime", translate("间隔时间 (分钟)"),
        translate("检测间隔的时间，每隔多久检测指定的IP通断一次"))
for s=1,60 do
checktime:value(s)
end
checktime:depends("check", "1")

cmdmode = s:taboption("infos",ListValue, "cmdmode", translate(""))
cmdmode:value("原版")
cmdmode:value("表格式")

local process_status = luci.sys.exec("ps | grep vnt-cli | grep -v grep")

vnt_info = s:taboption("infos", Button, "vnt_info" )
vnt_info.rawhtml = true
vnt_info:depends("cmdmode", "表格式")
vnt_info.template = "vnt/vnt_info"

btn1 = s:taboption("infos", Button, "btn1")
btn1.inputtitle = translate("本机设备信息")
btn1.description = translate("点击按钮刷新，查看当前设备信息")
btn1.inputstyle = "apply"
btn1:depends("cmdmode", "原版")
btn1.write = function()
if process_status ~= "" then
   luci.sys.call("$(uci -q get vnt.@vnt-cli[0].clibin) --info >/tmp/vnt-cli_info")
else
    luci.sys.call("echo '错误：程序未运行！请启动程序后重新点击刷新' >/tmp/vnt-cli_info")
end
end

btn1info = s:taboption("infos", DummyValue, "btn1info")
btn1info.rawhtml = true
btn1info:depends("cmdmode", "原版")
btn1info.cfgvalue = function(self, section)
    local content = nixio.fs.readfile("/tmp/vnt-cli_info") or ""
    return string.format("<pre>%s</pre>", luci.util.pcdata(content))
end

vnt_all = s:taboption("infos", Button, "vnt_all" )
vnt_all.rawhtml = true
vnt_all:depends("cmdmode", "表格式")
vnt_all.template = "vnt/vnt_all"

btn2 = s:taboption("infos", Button, "btn2")
btn2.inputtitle = translate("所有设备信息")
btn2.description = translate("点击按钮刷新，查看所有设备详细信息")
btn2.inputstyle = "apply"
btn2:depends("cmdmode", "原版")
btn2.write = function()
if process_status ~= "" then
    luci.sys.call("$(uci -q get vnt.@vnt-cli[0].clibin) --all >/tmp/vnt-cli_all")
else
    luci.sys.call("echo '错误：程序未运行！请启动程序后重新点击刷新' >/tmp/vnt-cli_all")
end
end

btn2all = s:taboption("infos", DummyValue, "btn2all")
btn2all.rawhtml = true
btn2all:depends("cmdmode", "原版")
btn2all.cfgvalue = function(self, section)
    local content = nixio.fs.readfile("/tmp/vnt-cli_all") or ""
    return string.format("<pre>%s</pre>", luci.util.pcdata(content))
end

vnt_list = s:taboption("infos", Button, "vnt_list" )
vnt_list.rawhtml = true
vnt_list:depends("cmdmode", "表格式")
vnt_list.template = "vnt/vnt_list"

btn3 = s:taboption("infos", Button, "btn3")
btn3.inputtitle = translate("所有设备列表")
btn3.description = translate("点击按钮刷新，查看所有设备列表")
btn3.inputstyle = "apply"
btn3:depends("cmdmode", "原版")
btn3.write = function()
if process_status ~= "" then
    luci.sys.call("$(uci -q get vnt.@vnt-cli[0].clibin) --list >/tmp/vnt-cli_list")
else
    luci.sys.call("echo '错误：程序未运行！请启动程序后重新点击刷新' >/tmp/vnt-cli_list")
end
end

btn3list = s:taboption("infos", DummyValue, "btn3list")
btn3list.rawhtml = true
btn3list:depends("cmdmode", "原版")
btn3list.cfgvalue = function(self, section)
    local content = nixio.fs.readfile("/tmp/vnt-cli_list") or ""
    return string.format("<pre>%s</pre>", luci.util.pcdata(content))
end

vnt_route = s:taboption("infos", Button, "vnt_route" )
vnt_route.rawhtml = true
vnt_route:depends("cmdmode", "表格式")
vnt_route.template = "vnt/vnt_route"

btn4 = s:taboption("infos", Button, "btn4")
btn4.inputtitle = translate("路由转发信息")
btn4.description = translate("点击按钮刷新，查看本机路由转发路径")
btn4.inputstyle = "apply"
btn4:depends("cmdmode", "原版")
btn4.write = function()
if process_status ~= "" then
    luci.sys.call("$(uci -q get vnt.@vnt-cli[0].clibin) --route >/tmp/vnt-cli_route")
else
    luci.sys.call("echo '错误：程序未运行！请启动程序后重新点击刷新' >/tmp/vnt-cli_route")
end
end

btn4route = s:taboption("infos", DummyValue, "btn4route")
btn4route.rawhtml = true
btn4route:depends("cmdmode", "原版")
btn4route.cfgvalue = function(self, section)
    local content = nixio.fs.readfile("/tmp/vnt-cli_route") or ""
    return string.format("<pre>%s</pre>", luci.util.pcdata(content))
end

btnchart = s:taboption("infos", Button, "btnchart")
btnchart.inputtitle = translate("设备流量统计")
btnchart.description = translate("点击按钮刷新，查看所有设备流量统计")
btnchart.inputstyle = "apply"
btnchart:depends({ cmdmode = "原版", disable_stats = "1" })
btnchart.write = function()
if process_status ~= "" then
    luci.sys.call("$(uci -q get vnt.@vnt-cli[0].clibin) --chart_a >/tmp/vnt-cli_chart")
else
    luci.sys.call("echo '错误：程序未运行！请启动程序后重新点击刷新' >/tmp/vnt-cli_chart")
end
end

btn4chart = s:taboption("infos", DummyValue, "btn4chart")
btn4chart.rawhtml = true
btn4chart:depends("cmdmode", "原版")
btn4chart.cfgvalue = function(self, section)
    local content = nixio.fs.readfile("/tmp/vnt-cli_chart") or ""
    return string.format("<pre>%s</pre>", luci.util.pcdata(content))
end

vnt_cmd = s:taboption("infos", Button, "vnt_cmd" )
vnt_cmd.rawhtml = true
vnt_cmd:depends("cmdmode", "表格式")
vnt_cmd.template = "vnt/vnt_cmd"

return m
