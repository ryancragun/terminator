require 'spec_helper'

# Validator specs
module RsTerminator
  describe Validator, 'validate_resource' do
    it 'raises an error if an invalid resource is passed' do
      expect { Validator.validate_resource(:invalid_resource) }
        .to raise_error(Exception::InvalidResource)
    end

    context 'it accepts all valid resources' do
      %i(server server_array instance snapshot volume).each do |resource|
        it "accepts all #{resource.to_s}" do
          Validator.validate_resource(resource).should eq(true)
        end
      end
    end
  end
end
