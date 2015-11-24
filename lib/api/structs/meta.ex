# make handler an enumeration so it could use say numbers? or use atoms?
# unsure the latter would JSON-serialize well for AMQP, though I may wanna ditch that altogether...
defmodule Meta do
  defstruct req: %MsgIn{}, handler: "RESP", user: "", route: "", misc: %{}
end
