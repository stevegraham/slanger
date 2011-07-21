module Slanger
  Redis = EM::Hiredis.connect if EM.reactor_running?
end