require 'spec_helper'

# RsTerminator.new
module RsTerminator
  describe RsTerminator, '.new', :rs_api do
    %i(server server_array instance snapshot volume).each do |resource|
      let(:klass) do
        camel = resource.to_s.split('_').map { |w| w.capitalize }.join
        Object.const_get("RsTerminator::#{camel}")
      end

      let(:terminator) do
        klass.new do
          email       'jane@doe.org'
          account_id  '1232'
          password    'drowssap'
        end
      end

      it 'takes a config block and retuns an instance' do
        expect(terminator.class).to eq(klass)
      end

      context 'allows all parameters to be created in a block' do
        subject do
          klass.new do
            hours         90
            safe_words    %w(test)
            safe_tags     %w(terminator:save=true)
            email         'john@doe.com'
            password      '3L337P455W0RD'
            account_id    '349005'
            use_tag_hours true
            api_filters   ['name==test']
          end
        end
        its(:hours)         { should eq(90) }
        its(:safe_words)    { should eq(%w(test)) }
        its(:safe_tags)     { should eq(%w(terminator:save=true)) }
        its(:email)         { should eq('john@doe.com') }
        its(:password)      { should eq('3L337P455W0RD') }
        its(:account_id)    { should eq('349005') }
        its(:use_tag_hours) { should eq(true) }
        its(:api_filters)   { should eq(['name==test']) }
      end

      it 'raises an error if an invalid method is passed in the block' do
        expect { klass.new { invalid_method } }
          .to raise_error(Exception::InvalidParameter)
      end

      it 'raises an error if account_id is not set' do
        expect { klass.new { password '1234'; email 'test@joe.com' } }
          .to raise_error(Exception::MissingRequiredParameter)
      end

      it 'raises an error if email is not set' do
        expect { klass.new { password '1234'; account_id '5678' } }
          .to raise_error(Exception::MissingRequiredParameter)
      end

      it 'raises an error if password is not set' do
        expect { klass.new { account_id '1234'; email 'test@joe.com' } }
          .to raise_error(Exception::MissingRequiredParameter)
      end

      it 'creates a right_api_client instance' do
        expect(terminator.instance_variable_get(:@client)).to be(@fake_client)
      end
    end
  end
end
