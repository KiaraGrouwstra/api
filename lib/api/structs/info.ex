defmodule Info do
  defstruct msg: %MsgOut{}, meta: %Meta{}
end

# defmodule Info do
#   defstruct msg: %{body: %{}, cb_id: -1, status: 200},
#     meta: %{req: %{body: %{}, cb_id: -1, headers: %{}}, handler: "RESP", user: "", route: ""}
# end
