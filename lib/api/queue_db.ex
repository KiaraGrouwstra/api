# mix amnesia.drop -db QueueDB
# mix amnesia.create -db QueueDB --disk
use Amnesia
defdatabase QueueDB do

  deftable Queue, [:domain, :queue], type: :set do
    @type t :: %Queue{domain: String.t, queue: String.t} # Any
  end

  # # clean the boilerplate out of table declarations
  # def deftbl(name, prop_map, opts \\ [type: :ordered_set, index: []]) do
  #   deftable name, [:id] ++ Map.keys(prop_map), opts do
  #     @type t :: %name{ %{id: non_neg_integer} |> Map.merge(prop_map) }
  #   end
  #   # for each type like User in the prop_map submit its type as a non_neg_integer but add user(!) methods for it.
  #   # https://github.com/meh/amnesia
  #   # unfortunately the User side needs outside information to add the appropriate messages(!)/add_message(!) methods there...
  # end

end
