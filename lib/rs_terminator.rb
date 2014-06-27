require 'right_api_client'
require 'threach'
require 'logger'
require 'time'
require 'rs_terminator/version'
require 'rs_terminator/exception'
require 'rs_terminator/validator'
require 'rs_terminator/core_ext/enumerable'
require 'rs_terminator/terminators/base_terminator'
require 'rs_terminator/terminators/instance'
require 'rs_terminator/terminators/server'
require 'rs_terminator/terminators/server_array'
require 'rs_terminator/terminators/volume'
require 'rs_terminator/terminators/snapshot'
require 'rs_terminator/worker'

# Module level builder
module RsTerminator
  def self.configure(resource, opts = {}, &block)
    Validator.validate_resource(resource)
    camel = resource.to_s.split('_').map { |w| w.capitalize }.join
    klass = Object.const_get("#{name}::#{camel}")
    klass.new(opts, &block)
  end
end
