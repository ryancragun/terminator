require 'spec_helper'

# Snapshot specs
module RsTerminator
  describe Snapshot, '.new', :rs_api do
    subject do
      Snapshot.new do
        account_id  '123'
        email       'test@example.com'
        password    'passw0rd'
      end
    end

    its(:hours) { should eq(744) }

  end
end
