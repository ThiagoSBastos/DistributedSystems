local luarpc = require("luarpc")

local port1 = 0
if arg[1] then
  port1 = arg[1]
else
  print("Choose a port for server 1")
  port1 = io.read("*n")
end

local IP = "0.0.0.0" -- IP default val
if arg[2] then
  IP = arg[2]
end

-- interface file
local idl = io.open("interface.txt", "r"):read("*a")

local p1 = luarpc.createProxy(IP, port1, idl)
--local ans = p1:boo(10)

--print("The ans 1 is " .. ans[1])

--local t,p = p1:boo(10)

--print("t: ".. t .. " and p: " .. p)

-- local p2 = luarpc.createProxy(IP, port2, idl)
 local r, s = p1:foo(3, "alo", {nome = "Aaa", idade = 20, peso = 55.0}, 1)
-- local t, p = p2:boo(10)
