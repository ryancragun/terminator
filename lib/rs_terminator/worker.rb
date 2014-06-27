# RsTerminator
module RsTerminator
  # Terminator Worker
  class Worker
    include Exception

    attr_reader :status, :client, :rs_resource, :message

    def initialize(rs_resource, api_client = nil, instance_variable_hash)
      @status = :initialized
      @rs_resource = rs_resource
      self.client = api_client
      import_instance_variable_hash(instance_variable_hash)
    end

    def terminate
      @status = :running
      safe_to_destroy? ? destroy : skip
    rescue => e
      @message = {
        message: e.message,
        backtrace: e.backtrace,
        last_request: @client.last_request
      }
      @status = :error
    end

    def client=(client)
      @client = client
      @rs_resource.instance_variable_set(:@client, client)
    end

    private

    def import_instance_variable_hash(hash)
      hash.each { |k, v| instance_variable_set(k, v) }
    end

    def safe_to_destroy?
      !safe_word? && !locked? && !safe_tag? && expired?
    end

    def locked?
      if @rs_resource.respond_to?(:locked)
        @rs_resource.locked
      else
        false
      end
    end

    def destroy
      if @dry_run
        @message = { message: "dry_run termination for #{@rs_resource.name}" }
        return @status = :dry_run_destroyed
      elsif @rs_resource.respond_to?(:terminate)
        @rs_resource.terminate
      elsif @rs_resource.respond_to?(:destroy)
        @rs_resource.destroy
      else
        msg = "Unknown destroy method, know methods: #{@rs_resource.methods}"
        @message = { message: msg }
        return @status = :error
      end
      @message = { last_request: @client.last_request }
      @status = :destroyed
    end

    def skip
      @message = { message: "skipped #{@rs_resource.name}" }
      tag_discovery_time unless discovery_tag?
      @status = :skipped
    end

    def safe_word?
      @safe_words.any? do |word|
        @rs_resource.name.downcase =~ /#{word.downcase}/
      end
    end

    def safe_tag?
      !(@safe_tags & tags).empty?
    end

    def tags
      @tags ||= begin
        @client
          .tags.by_resource(resource_hrefs: [@rs_resource.href])
          .first.tags.map(&:values).flatten
      end
    end

    def expired?
      Time.now > allowed_time
    end

    def allowed_time
      discovery_time + ((hours_from_tag || @hours) * 60 * 60)
    end

    def discovery_time
      @discovery_time ||= begin
        if discovery_tag?
          tag = tags.select { |t| t =~ /rs_terminator:discovery_time=/ }.first
          Time.parse(tag.scan(/rs_terminator:discovery_time=(.+)/)[0][0])
        else
          Time.now
        end
      end
    end

    def discovery_tag?
      tags.any? { |t| t =~ /rs_terminator:discovery_time/ }
    end

    def hours_from_tag
      return false unless @use_tag_hours
      hours = []
      @safe_tags.each do |safe_tag|
        tags.each do |resource_tag|
          safe_namespace = safe_tag.split('=').first
          if resource_tag =~ /#{safe_namespace}=(\d+)/
            hours << Regexp.last_match(1).to_i
          end
        end
      end
      hours.min
    end

    def tag_discovery_time
      now = Time.now
      @client.tags.multi_add(
        resource_hrefs: [@rs_resource.href],
        tags: ["rs_terminator:discovery_time=#{now}"]
      )
      @discovery_time = now
    end
  end
end
