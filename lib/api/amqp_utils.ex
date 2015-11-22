# defmodule AMQP.Utils do
#
#   # crap I had to copy over for this to work:
#   # https://github.com/pma/amqp/blob/master/lib/amqp/utils.ex
#
#   def to_type_tuple(fields) when is_list(fields) do
#     Enum.map fields, &to_type_tuple/1
#   end
#   def to_type_tuple(:undefined), do: :undefined
#   def to_type_tuple({name, type, value}), do: {to_string(name), type, value}
#   def to_type_tuple({name, value}) when is_boolean(value) do
#     to_type_tuple {name, :bool, value}
#   end
#   def to_type_tuple({name, value}) when is_bitstring(value) or is_atom(value) do
#     to_type_tuple {name, :longstr, to_string(value)}
#   end
#   def to_type_tuple({name, value}) when is_integer(value) do
#     to_type_tuple {name, :long, value}
#   end
#   def to_type_tuple({name, value}) when is_float(value) do
#     to_type_tuple {name, :float, value}
#   end
#
#   # the part I actually added...
#
#   def to_type_tuple({name, value}) when is_list(value) or is_map(value) do
#     # to_type_tuple {name, :array, value}
#     json = Poison.Encoder.encode(value, []) |> to_string()
#     to_type_tuple {name, :longstr, json}
#   end
#
# end
