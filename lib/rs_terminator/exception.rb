module RsTerminator
  # Errors to mix into our classes
  module Exception
    class InvalidResource < StandardError; end
    class InvalidParameter < StandardError; end
    class MissingRequiredParameter < StandardError; end
    class NotImplemented < StandardError; end
    class WorkerError < StandardError; end
  end
end
