module RsTerminator
  # RsTerminator Snapshot
  class Snapshot
    include BaseTerminator

    private

    def setup_class
      @hours = 744
    end

    def build_workers
      instance_variable_hash = parameter_instance_variable_hash
      snapshots = existing_snapshots
      @logger.debug "Building #{snapshots.count} Workers"
      snapshots.each do |rs_instance|
        @workers << Worker.new(rs_instance, @client, instance_variable_hash)
      end
    end

    def existing_snapshots
      @existing_snapshots ||= begin
        snapshots = []
        msg = "Searching for snapshots with #{@api_filters.inspect} filters"
        @logger.debug msg
        @client
          .clouds
          .index
          .select { |cloud| cloud.respond_to?(:volume_snapshots) }
          .concurrent_each_with_element(@client_pool) do |cloud, client|
            cloud.instance_variable_set(:@client, client)
            cloud.volume_snapshots.index(filter: @api_filters).each do |snap|
              snapshots << snap
            end
          end
        snapshots
      end
    end
  end
end
