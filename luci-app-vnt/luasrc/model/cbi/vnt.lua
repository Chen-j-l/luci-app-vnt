local http = luci.http
local nixio = require "nixio"

m = Map("vnt")
m.description = translate('vnt是一个简便高效的异地组网、内网穿透工具。')

m:section(SimpleSection).template  = "vnt/vnt_status"

s = m:section(TypedSection, "vnt", translate("vnt设置"))
s.anonymous = true

s:tab("general", translate("基本设置"))
s:tab("privacy", translate("高级设置"))
s:tab("infos", translate("连接信息"))
s:tab("logs", translate("日志"))

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
token.placeholder = "token"
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

passmode = s:taboption("general",ListValue, "passmode", translate("加密模式"),
	translate("默认off不加密，通常情况aes_gcm安全性高、aes_ecb性能更好，在低性能设备上aes_ecb、chacha20、chacha20_poly1305、xor速度最快<br>注意：xor为数据混淆，并不是一种强大的加密算法，易被破解，因此不适合用于真正的加密需求"))
passmode:value("off",translate("不加密"))
passmode:value("aes_ecb")
passmode:value("sm4_cbc")
passmode:value("aes_cbc")
passmode:value("aes_gcm")
passmode:value("chacha20")
passmode:value("chacha20_poly1305")
passmode:value("xor")

key = s:taboption("general",Value, "key", translate("加密密钥"),
	translate("端对端加密，使用相同密钥的客户端之间才能通信，服务端无法解密"))
key.placeholder = "wodemima"
key.password = true
key:depends("passmode", "aes_ecb")
key:depends("passmode", "sm4_cbc")
key:depends("passmode", "sm4_cbc")
key:depends("passmode", "aes_gcm")
key:depends("passmode", "chacha20")
key:depends("passmode", "chacha20_poly1305")
key:depends("passmode", "xor")

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

log = s:taboption("general",Flag, "log", translate("启用日志"),
	translate("运行日志在/tmp/vnt.log,可在上方客户端日志查看"))
log.rmempty = false

vntshost = s:taboption("privacy", Value, "vntshost", translate("vnts服务器地址"),
	translate("相同的服务器，相同token的设备才会组成一个局域网，协议支持使用tcp://和ws://和wss://及默认udp://"))
vntshost.placeholder = "tcp://域名:端口"

vntdns = s:taboption("privacy",DynamicList, "vntdns", translate("DNS服务器"),
	translate("指定DNS服务器地址,可使用多个dns,不指定时使用系统解析"))
vntdns.placeholder = "8.8.8.8:53"

stunhost = s:taboption("privacy",DynamicList, "stunhost", translate("stun服务器地址"),
	translate("使用stun服务探测客户端NAT类型，不同类型有不同的打洞策略，最多三个，超过将被忽略，可不填"))
stunhost.placeholder = "stun.qq.com:3478"

local model = nixio.fs.readfile("/proc/device-tree/model") or ""
local hostname = nixio.fs.readfile("/proc/sys/kernel/hostname") or ""
model = model:gsub("\n", "")
hostname = hostname:gsub("\n", "")
local host_name = (model ~= "" and model) or (hostname ~= "" and hostname) or "OpenWrt"
host_name = host_name:gsub(" ", "_")
host_name = s:taboption("privacy", Value, "device_name", translate("设备名称"),
	translate("本机设备名称，方便区分不同设备"))
device_name.placeholder = host_name
device_name.default = host_name

tunname = s:taboption("privacy",Value, "tunname", translate("虚拟网卡名称"),
	translate("自定义虚拟网卡的名称，在多开时虚拟网卡名称不能相同，默认为 vnt-tun"))
tunname.placeholder = "vnt-tun"

relay = s:taboption("privacy",ListValue, "relay", translate("传输模式"),
	translate("可以强制要求P2P或转发"))
relay:value("自动")
relay:value("转发")
relay:value("P2P")

client_port = s:taboption("privacy", Value, "client_port", translate("本地监听端口"),
	translate("指定本地监听的端口组,多个端口可以并发分摊流量<br>例1：12345,12346,12347 表示udp监听12345、12346、12347端口，tcp监听12345端口<br>例2：0,0 表示udp监听两个未使用的端口，tcp监听一个未使用的端口"))
client_port.placeholder = "0,0"

mapping = s:taboption("privacy",DynamicList, "mapping", translate("端口映射"),
	translate("端口映射,可以设置多个映射地址，例如tcp:0.0.0.0:80-10.26.0.11:81<br>表示将本地tcp 80端口的数据转发到10.26.0.11:81<br>转发的目的地址可以使用域名+端口"))

mtu = s:taboption("privacy",Value, "mtu", translate("MTU"),
	translate("设置虚拟网卡的mtu值，默认值：不加密1450，加密1410"))
mtu.datatype = "range(1,1500)"

punch = s:taboption("privacy",ListValue, "punch", translate("打洞模式"),
	translate("根据实际情况选择打洞方法"))
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
	translate("用服务端通信的数据加密，采用rsa+aes256gcm加密客户端和服务端之间通信的数据，可以避免token泄漏、中间人攻击"))
serverw.rmempty = false

finger = s:taboption("privacy",Flag, "finger", translate("启用数据指纹校验"),
	translate("对中转的数据做校验，可增加安全性，如果服务端开启指纹校验，则客户端也必须开启，开启会损耗一部分性能"))
finger.rmempty = false

first_latency = s:taboption("privacy",Flag, "first_latency", translate("启用延迟优先优化传输"),
	translate("某些情况下可能p2p比中继延迟更高，启用后优先走延迟最低的链路，否则优先走P2P通道"))
first_latency.rmempty = false

local process_status = luci.sys.exec("ps | grep vnt-cli | grep -v grep")

vnt_all = s:taboption("infos", Button, "vnt_all")
vnt_all.rawhtml = true
vnt_all.template = "vnt/vnt_all"

logs = s:taboption("logs", DummyValue, "logs")
logs.rawhtml = true
logs.template = "vnt/vnt_log"

return m
