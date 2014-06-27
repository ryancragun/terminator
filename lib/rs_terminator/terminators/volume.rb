module RsTerminator
  # RsTerminator Volume
  class Volume
    include BaseTerminator

    private

    def setup_class
      @hours = 744
    end

    def build_workers
      instance_variable_hash = parameter_instance_variable_hash
      volumes = existing_volumes
      @logger.debug "Building #{volumes.count} Workers"
      volumes.each do |rs_instance|
        @workers << Worker.new(rs_instance, @client, instance_variable_hash)
      end
    end

    def existing_volumes
      @existing_volumes ||= begin
        volumes = []
        msg = "Searching for Volumes with #{@api_filters.inspect} filters"
        @logger.debug msg
        @client
          .clouds
          .index
          .select { |cloud| cloud.respond_to?(:volumes) }
          .concurrent_each_with_element(@client_pool) do |cloud, client|
            cloud.instance_variable_set(:@client, client)
            cloud.volumes.index(filter: @api_filters).each do |volume|
              volumes << volume
            end
          end
        volumes
      end
    end
  end
end
