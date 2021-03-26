local luarpc = require("luarpc")

-- objects
local myobj1 = {
  foo = function (a, s, st, n)
      return a*2, string.len(s) + st.idade + n
    end,
  add = function (a, b, c)
    return a + b + c
  end,
  boo = function (n)
      return n, { nome = "Bia", idade = 30, peso = 61.0}
  end
}

local myobj2 = {
  foo =
    function (a, s, st, n)
      return 0.0, 1
    end,
  boo =
    function (n)
      return 1, { nome = "Teo", idade = 60, peso = 73.0}
    end
}

-- interface file
local idl = "interface.lua"

-- create all servants
local ip, port = luarpc.createServant(myobj1 , idl)
print("Server IP: " .. ip)
print("Server port: " .. port)

-- local serv2 = luarpc.createServant(myobj2, idl)


luarpc.waitIncoming()
