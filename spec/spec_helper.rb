require 'rubygems'
require 'bundler/setup'
require 'rs_terminator'

RSpec.configure do |rspec|
  rspec.treat_symbols_as_metadata_keys_with_true_values = true
  rspec.run_all_when_everything_filtered = true
  rspec.filter_run :focus
  rspec.order = 'random'
  rspec.before(:each, rs_api: true) do
    @fake_client = double('fake_client', log: Logger.new($stdout))
    allow(RightApi::Client).to receive(:new).and_return(@fake_client)
  end
end
