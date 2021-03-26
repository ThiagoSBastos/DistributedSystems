local luarpc = require("luarpc")

local IP = "localhost"

print("Choose a port for server 1")
local port1 = io.read("*n")

-- print("Choose a port for server 2")
-- local port2 = io.read("*n")

-- interface file
local idl = "interface.lua"

local p1 = luarpc.createProxy(IP, port1, idl)
local ans = p1:add(5, 25, 45)
print("The ans 1 is " .. ans)

--local t,p = p1:boo(10)

--print("t: ".. t .. " and p: " .. p)


-- print('the answer is ' .. p1)

-- local p2 = luarpc.createProxy(IP, port2, idl)
-- local r, s = p1:foo(3, "alo", {nome = "Aaa", idade = 20, peso = 55.0})
-- local t, p = p2:boo(10)
