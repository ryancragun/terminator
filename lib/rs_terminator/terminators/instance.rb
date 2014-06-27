module RsTerminator
  # RsTerminator Instance
  class Instance
    include BaseTerminator

    private

    def setup_class
      @hours = 24
      @api_filters = %w(state==operational)
    end

    def build_workers
      instance_variable_hash = parameter_instance_variable_hash
      instances = active_instances
      @logger.debug "Building #{instances.count} Workers"
      instances.each do |rs_instance|
        @workers << Worker.new(rs_instance, @client, instance_variable_hash)
      end
    end

    def active_instances
      @active_instances ||= begin
        instances = []
        msg = "Searching for Instances with #{@api_filters.inspect} filters"
        @logger.debug msg
        @client
          .clouds
          .index
          .concurrent_each_with_element(@client_pool) do |cloud, client|
            cloud.instance_variable_set(:@client, client)
            cloud.instances.index(filter: @api_filters).each do |inst|
              instances << inst
            end
            cloud.instance_variable_set(:@client, nil)
          end
        instances
      end
    end
  end
end
