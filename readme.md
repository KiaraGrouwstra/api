mix deps.get
mix phoenix.server

# mix amnesia.drop -db QueueDB
rm -rf Mnesia.nonode@nohost
mix amnesia.create -db QueueDB --disk

./start-dev.sh
http://localhost:8000/_utils/

TODO:
- fix bug causing fetch to only happen after server restart
- switch to promises to invert horrible callback architecture to something more functional
  - send completes too
- switch to mutable queue allowing elixir objects without silly serialization
- fix domain recognition in utils.ex:url_domain/1
- custom cool-downs per domain
- debug tests
- implement retry count
- preserving state (not losing sockets/jobs) through restart?
- fix decoder
- throttler: fix timing, the ticks don't necessarily happen at .000
- throttler: how should the blocking work with GenServer's standard 5s timeout?
- ditch Phoenix
- distribute
- ditch handlers for empty domain queues? should work on a failed pop -- no free fetch credit loophole.
