module RsTerminator
  # RsTerminator Server
  class Server
    include BaseTerminator

    private

    def setup_class
      @hours = 24
    end

    def build_workers
      instance_variable_hash = parameter_instance_variable_hash
      instances = active_instances
      @logger.debug 'Building Workers'
      instances.each do |rs_instance|
        @workers << Worker.new(rs_instance, @client, instance_variable_hash)
      end
    end

    def active_instances
      @active_instancs ||= begin
        instances = []
        active_servers
          .concurrent_each_with_element(@client_pool) do |server, client|
            server.instance_variable_set(:@client, client)
            instances << server.show
            server.instance_variable_set(:@client, nil)
          end
        instances
      end
    end

    def active_servers
      filters = @api_filters.empty? ? 'no' : @api_filters.inspect
      msg = "Searching for Servers with #{filters} filters."
      @logger.debug msg
      @client
        .servers
        .index(filter: @api_filters)
        .select { |server| active?(server) }
    end

    def active?(server)
      server.state !~ /inactive|decommissioning|terminated/
    end
  end
end
