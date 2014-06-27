require 'spec_helper'

# ServerArray specs
module RsTerminator
  describe ServerArray, '.new', :rs_api do
    subject do
      ServerArray.new do
        account_id  '123'
        email       'test@example.com'
        password    'passw0rd'
      end
    end

    its(:hours) { should eq(24) }

  end
end
