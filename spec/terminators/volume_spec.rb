require 'spec_helper'

# Volume specs
module RsTerminator
  describe Volume, '.new', :rs_api do
    subject do
      Volume.new do
        account_id  '123'
        email       'test@example.com'
        password    'passw0rd'
      end
    end

    its(:hours) { should eq(744) }

  end
end
