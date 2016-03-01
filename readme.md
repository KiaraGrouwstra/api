mix deps.get
mix phoenix.server

mix amnesia.drop -db QueueDB
mix amnesia.create -db QueueDB --disk

./start-dev.sh
http://localhost:8000/_utils/
