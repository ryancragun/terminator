require 'spec_helper'

# RsTerminator factory
module RsTerminator
  describe RsTerminator, '.configure' do
    %i(server server_array instance snapshot volume).each do |type|
      let(:block) { -> {} }
      let(:opts) { double }
      let(:resource) { type }
      let(:klass) do
        camel = type.to_s.split('_').map { |w| w.capitalize }.join
        Object.const_get("RsTerminator::#{camel}")
      end

      it 'validates resource sym, creates class instance and proxies block' do
        allow(Validator).to receive(:validate_resource).with(resource)
        allow(klass).to receive(:new).with(opts, &block)

        Validator.should_receive(:validate_resource).with(resource)
        klass.should_receive(:new).with(opts, &block)

        RsTerminator.configure(resource, opts) { block }
      end
    end
  end
end
