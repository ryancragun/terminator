module RsTerminator
  # RsTerminator ServerArray
  class ServerArray
    include BaseTerminator

    private

    def setup_class
      @hours = 24
    end

    def build_workers
      instance_variable_hash = parameter_instance_variable_hash
      @logger.debug 'Building Workers'
      active_instances.each do |rs_instance|
        @workers << Worker.new(rs_instance, @client, instance_variable_hash)
      end
    end

    def active_instances
      @active_instancs ||= begin
        instances = []
        active_server_arrays
          .concurrent_each_with_element(@client_pool) do |array, client|
            array.instance_variable_set(:@client, client)
            array.current_instances.index.each do |instance|
              instances << instance
            end
            array.instance_variable_set(:@client, nil)
          end
        instances
      end
    end

    def active_server_arrays
      filters = @api_filters.empty? ? 'no' : @api_filters.inspect
      msg = "Searching for ServerArrays with #{filters} filters."
      @logger.debug msg
      @client
        .server_arrays
        .index(filter: @api_filters)
        .select { |array| array.instances_count > 0 }
    end
  end
end
