# Lark

Lark is a simple system to store local cache in a cluster of redis servers, be
able to query state about other lark nodes, and notice when one goes offline.

    Lark.on_expire do |id|
      Log.debug "Lost node #{id}"
    end

    EM.start do
      lark = Lark.new "bottom_node.1", :expire => 60
      lark.set "ip" => "127.0.0.1", "role" => "worker node"
      EM::PeriodicTimer(5) do
        lark.set "load" => get_load, "mem_usage" => get_mem_usage
      end

      on_some_event do
        lark.find(/^top_node/).each do |id, data|
          check_on_node(id, data)
        do
      end
    end
