require 'spec_helper'

# Worker specs
module RsTerminator
  describe Worker do
    parameter_instance_variable_hash = {
      :@thread_count  => 5,
      :@use_tag_hours => false,
      :@api_filters   => [],
      :@safe_words    => %w(save SAVE keep_me),
      :@safe_tags     => %w(rs_terminator:save=true terminator:save=true),
      :@hours         => 24,
      :@dry_run       => false,
      :@email         => 'tester@testtube.org',
      :@password      => '3423098420adasda9304ui',
      :@account_id    => '7234234'
    }

    save_array = [
      { 'name' => 'fake:tag=false' },
      { 'name' => 'some_tag:hours=72' },
      { 'name' => 'rs_terminator:save=true' }
    ]
    no_save_array = [
      { 'name' => 'fake:tag=false' },
      { 'name' => 'rs_terminator:save=80' },
      { 'name' => 'some_tag:hours=72' }
    ]

    # mock a RsTerminator::Server instance
    let(:rs_instance_hash)    { parameter_instance_variable_hash }

    # mock a RightApi::Client resource
    let(:resource_save) do double(
      'r_save', destroy: true, name: 'save me', href: 'www.test.uk')
    end
    let(:resource_no_save) do double(
      'r_no_save', destroy: true, name: 'name', href: 'www.test.uk')
    end

    # stub just enough of the RS API
    let(:api_save) do double(
      'api_client',
      tags: double(
        'tags_resource',
        by_resource: double(
          'tags_response_array',
          first: double(
            'tag_response',
            tags: save_array)),
        multi_add: true),
      last_request: true)
    end
    let(:api_no_save) do double(
      'api_client',
      tags: double(
        'tags_resource',
        by_resource: double(
          'tags_response_array',
          first: double(
            'tag_response',
            tags: no_save_array)),
        multi_add: true),
      last_request: true)
    end

    describe '.new' do
      it 'properly initialized an instance of the class' do
        worker = Worker.new(resource_save, api_save, rs_instance_hash)
        expect(worker.instance_variable_get(:@client)).to eq(api_save)
        res = resource_save
        expect(worker.instance_variable_get(:@rs_resource)).to eq(res)
        expect(worker.instance_variable_get(:@thread_count)).to eq(5)
        expect(worker.instance_variable_get(:@account_id)).to eq('7234234')
      end
    end

    describe '.terminate' do
      it 'destroys resource when given no safeties and it is expired' do
        more_than_24hrs =  Time.now - (60 * 60 * 25)
        worker = Worker.new(resource_no_save, api_no_save, rs_instance_hash)
        worker.instance_variable_set(:@discovery_time, more_than_24hrs)
        expect(resource_no_save).to receive(:terminate)
        expect(worker.send(:safe_to_destroy?)).to eq(true)
        worker.terminate
        expect(worker.status).to eq(:destroyed)
      end

      it 'saves resource when given no safeties and it is not expired' do
        less_than_24hrs =  Time.now - (60 * 60 * 23)
        worker = Worker.new(resource_no_save, api_no_save, rs_instance_hash)
        worker.instance_variable_set(:@discovery_time, less_than_24hrs)
        expect(resource_no_save).not_to receive(:terminate)
        expect(worker.send(:expired?)).to eq(false)
        worker.terminate
        expect(worker.status).to eq(:skipped)
      end

      it 'skips resource when expired and has a safe word in name' do
        more_than_24hrs =  Time.now - (60 * 60 * 25)
        worker = Worker.new(resource_save, api_no_save, rs_instance_hash)
        worker.instance_variable_set(:@discovery_time, more_than_24hrs)
        expect(resource_save).not_to receive(:terminate)
        expect(worker.send(:safe_word?)).to eq(true)
        worker.terminate
        expect(worker.status).to eq(:skipped)
      end

      it 'skips resource when expired and has a safe tag' do
        worker = Worker.new(resource_no_save, api_save, rs_instance_hash)
        expect(resource_no_save).not_to receive(:terminate)
        expect(worker.send(:safe_tag?)).to eq(true)
        worker.terminate
        expect(worker.status).to eq(:skipped)
      end

      it 'uses the tag hours when they are enabled' do
        # The api_no_save mock will return a tags array with an allowed hours
        # of 80.  If the tags are being properly parsed worker1 (79hrs) should
        # be skipped and worker2 (81hrs) should be destroyed.

        less_than_80hrs =  Time.now - (60 * 60 * 79)
        more_than_80hrs = Time.now - (60 * 60 * 81)
        hash = rs_instance_hash.merge(:@use_tag_hours => true)

        worker1 = Worker.new(resource_no_save, api_no_save, hash)
        worker1.instance_variable_set(:@discovery_time, less_than_80hrs)
        expect(worker1.send(:hours_from_tag)).to eq(80)
        expect(worker1.send(:expired?)).to eq(false)
        worker1.terminate
        expect(worker1.status).to eq(:skipped)

        worker2 = Worker.new(resource_no_save, api_no_save, hash)
        worker2.instance_variable_set(:@discovery_time, more_than_80hrs)
        expect(worker2.send(:hours_from_tag)).to eq(80)
        expect(worker2.send(:expired?)).to eq(true)
        worker2.terminate
        expect(worker2.status).to eq(:destroyed)
      end

      it 'ignores the tags hours if the use_tag_hours param is false' do
        worker1 = Worker.new(resource_no_save, api_save, rs_instance_hash)
        expect(worker1.send(:hours_from_tag)).to eq(false)
      end

      it 'tags an undiscovered resource' do
        worker = Worker.new(resource_no_save, api_no_save, rs_instance_hash)
        expect(worker).to receive(:tag_discovery_time)
        worker.terminate
        expect(worker.status).to eq(:skipped)
      end

      it 'does not destroy resource when dry_run is true' do
        more_than_24hrs =  Time.now - (60 * 60 * 25)
        worker = Worker.new(resource_no_save, api_no_save, rs_instance_hash)
        worker.instance_variable_set(:@discovery_time, more_than_24hrs)
        worker.instance_variable_set(:@dry_run, true)
        expect(resource_no_save).to_not receive(:destroy)
        expect(resource_no_save).to_not receive(:terminate)
        worker.terminate
        expect(worker.status).to eq(:dry_run_destroyed)
      end
    end
  end
end
