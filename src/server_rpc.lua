local luarpc = require("luarpc")

-- objects
local myobj = {
  add = function (a, b)
    return a + b
  end
}

local myobj1 = {
  foo =
    function (a, s, st, n)
      return a*2, string.len(s) + st.idade + n
    end,
  boo =
    function (n)
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

--dofile(interface)

local serv1 = luarpc.createServant(myobj)--, interface)
--local serv2 = luarpc.createServant(myobj2)--, interface)


luarpc.waitIncoming()
