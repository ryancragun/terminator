# RsTerminator
module RsTerminator
# Base Terminator module that we'll mix into each Terminator Class.
  module BaseTerminator
    include Exception

    attr_reader :workers

    PARAMETERS =
      %w(hours safe_words safe_tags email password account_id dry_run
         api_filters use_tag_hours threads debug logger)
    REQUIRED_PARAMETERS =
      %w(account_id email password)

    def self.included(klass)
      klass.extend self
    end

    def initialize(opts = {}, &configuration)
      setup_default_parameters
      setup_class
      evaluate_config(&configuration) if block_given?
      evaluate_opts(opts) unless opts.empty?
      verify_required_params
      @client = create_rs_api_client
      setup_logger
      build_client_pool
    end

    PARAMETERS.each do |method|
      attr_writer method.to_sym
      class_eval <<-CODE_BLOCK, __FILE__, __LINE__ + 1
        def #{method}(value = nil)
          value && self.#{method}=value
          @#{method}
        end
      CODE_BLOCK
    end

    def terminate
      build_workers # implemented in each class
      @workers.concurrent_each_with_element(@client_pool) do |worker, client|
        worker.client = client
        worker.terminate
      end
    end

    def dry_run
      @dry_run = true
      terminate
    ensure
      @dry_run = false
    end

    def debug=(level)
      @debug = level
      setup_logger
    end

    private

    def setup_default_parameters
      @dry_run = false
      @threads = 1
      @workers = []
      @use_tag_hours = false
      @api_filters = []
      @safe_words = %w(save SAVE)
      @safe_tags = %w(rs_terminator:save=true terminator:save=true)
    end

    def setup_class
      not_implemented # Method is defined each each classes definition
    end

    def build_workers
      not_implemented # Method is defined each each classes definition
    end

    def setup_logger
      @logger ||= Logger.new($stdout)
      @logger.level = @debug ? Logger::DEBUG : Logger::INFO
      @client && @client.log(@logger)
    end

    def not_implemented
      fail NotImplmented, "Parent method isn't implemented for this class."
    end

    def create_rs_api_client
      client = RightApi::Client.new(
        account_id: @account_id.to_s,
        password:   @password.to_s,
        email:      @email.to_s
      )
      @logger && client.log(@logger)
      client
    end

    def evaluate_config(&block)
      instance_eval(&block)
    rescue NameError => e
      raise InvalidParameter, e.message
    end

    def evaluate_opts(hash)
      hash.each do |key, value|
        if PARAMETERS.any? { |param| param == key.to_s }
          instance_variable_set("@#{key}", value)
        end
      end
    end

    def verify_required_params
      params = REQUIRED_PARAMETERS.map do |required_param|
        param = "@#{required_param}".to_sym
        instance_variable_get(param)
      end
      msg = "You must provide #{REQUIRED_PARAMETERS.inspect} parameters"
      fail MissingRequiredParameter, msg unless params.none?(&:nil?)
    end

    def parameter_instance_variable_hash
      vars = instance_variables.map do |name|
        if PARAMETERS.map { |p| "@#{p}".to_sym }.any? { |s| name == s }
          [name, instance_variable_get(name)]
        end
      end
      Hash[vars.compact]
    end

    def build_client_pool
      @client_pool ||= begin
        client_pool = Queue.new
        msg = "Populating the client pool with #{@threads.to_s} instances"
        @logger.debug msg
        (1..@threads).threach(@threads) do
          client_pool << create_rs_api_client
        end
        client_pool
      end
    end
  end
end
