module RsTerminator
  # Validator class
  class Validator
    include Exception

    def self.validate_resource(resource)
      valid_resources = %i(server server_array instance volume snapshot)
      if !valid_resources.include?(resource)
        msg = "#{resource} is not a valid resource."
        msg << "Valid resources are #{valid_resources.inspect}"
        fail InvalidResource, msg
      else
        true
      end
    end
  end
end
