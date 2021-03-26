-- Customized type
--struct {
--  name = "minhaStruct",
--  fields = {
--    {name = "nome" , type = "string"},
--    {name = "peso" , type = "double"},
--    {name = "idade", type = "int"},
--  }
--}

-- Declare all supported types
interface {
  name = "minhaInt",
  methods = {
    add = {
      resulttype = "double",
      args = {
        {direction = "in", type = "double"},
        {direction = "in", type = "double"},
        {direction = "in", type = "double"},
        {direction = "out", type = "double"}
      }
    },
    foo = {
      resulttype = "double",
      args = {
        {direction = "in",  type = "double"},
        {direction = "in",  type = "string"},
        {direction = "in",  type = "minhaStruct"},
        {direction = "out", type = "int"}
      }
    },
    boo = {
      resulttype = "void",
      args = {
        {direction = "in",  type = "double"},
        {direction = "out", type = "minhaStruct"}
      }
    }
  }
}
