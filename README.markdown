# Lark

Lark is a simple system to store local cache in a cluster of redis servers, be
able to query state about other lark nodes, and notice when one goes offline.

    Lark.on_expired do |id|
      Log.debug "Lost node #{id}"
    end

    Lark.configure :domain => "staging", :expire => 60

    EM.run do
      lark = Lark::Base.new "bottom_node.1", "group3", "ip" => "127.0.0.1", "role" => "worker node"

      EM::PeriodicTimer.new(5) do
        lark.set "load" => get_load, "mem_usage" => get_mem_usage
      end

      on_some_event do
        Lark.get(:group3).each do |n|
          check_on_node(n)
        end
      end
    end
