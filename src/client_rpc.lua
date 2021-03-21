local luarpc = require("luarpc")

local IP = "0.0.0.0"

print("Choose a port")
local port1 = io.read("*n")

local p1 = luarpc.createProxy(IP, port1) --arq_interface)

-- local ans = p1:add(10, 1)

-- print('the answer is ' .. p1)

--local p2 = luarpc.createproxy(IP, porta2, arq_interface)
--local r, s = p1:foo(3, "alo", {nome = "Aaa", idade = 20, peso = 55.0})
--local t, p = p2:boo(10)
