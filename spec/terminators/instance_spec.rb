require 'spec_helper'

# Instance specs
module RsTerminator
  describe Instance, '.new', :rs_api do
    subject do
      Instance.new do
        account_id  '123'
        email       'test@example.com'
        password    'passw0rd'
      end
    end

    its(:hours) { should eq(24) }

  end
end
