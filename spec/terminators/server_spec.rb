require 'spec_helper'

# Server specs
module RsTerminator
  describe Server, '.new', :rs_api do
    subject do
      Server.new do
        account_id  '123'
        email       'test@example.com'
        password    'passw0rd'
      end
    end

    its(:hours) { should eq(24) }

  end
end
