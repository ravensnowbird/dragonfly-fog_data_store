require 'spec_helper'
require 'dragonfly/spec/data_store_examples'
require 'yaml'
require 'dragonfly/fog_data_store'

describe Dragonfly::FogDataStore do

  # To run these tests, put a file ".fog_spec.yml" in the dragonfly root dir, like this:
  # key: XXXXXXXXXX
  # secret: XXXXXXXXXX
  # enabled: true
  if File.exist?(file = File.expand_path('../../.fog_spec.yml', __FILE__))
    config = YAML.load_file(file)
    KEY = config['key']
    SECRET = config['secret']
    enabled = config['enabled']
  else
    enabled = false
  end

  if enabled

    # Make sure it's a new bucket name
    BUCKET_NAME = "dragonfly-test-#{Time.now.to_i.to_s(36)}"

    before(:each) do
      @data_store = Dragonfly::FogDataStore.new(
        bucket_name: BUCKET_NAME,
        rackspace_api_key: KEY,
        rackspace_username: SECRET
      )
    end

  else

    BUCKET_NAME = 'test-bucket'

    before(:each) do
      Fog.mock!
      @data_store = Dragonfly::FogDataStore.new(
        bucket_name: BUCKET_NAME,
        rackspace_api_key: 'XXXXXXXXX',
        rackspace_username: 'XXXXXXXXX'
      )
    end

  end

  it_should_behave_like 'data_store'

  let (:app) { Dragonfly.app }
  let (:content) { Dragonfly::Content.new(app, "eggheads") }
  let (:new_content) { Dragonfly::Content.new(app) }

  describe "registering with a symbol" do
    it "registers a symbol for configuring" do
      app.configure do
        datastore :fog
      end
      app.datastore.should be_a(Dragonfly::FogDataStore)
    end
  end

  describe "write" do
    it "should use the name from the content if set" do
      content.name = 'doobie.doo'
      uid = @data_store.write(content)
      uid.should =~ /doobie\.doo$/
      new_content.update(*@data_store.read(uid))
      new_content.data.should == 'eggheads'
    end

    it "should work ok with files with funny names" do
      content.name = "A Picture with many spaces in its name (at 20:00 pm).png"
      uid = @data_store.write(content)
      uid.should =~ /A_Picture_with_many_spaces_in_its_name_at_20_00_pm_\.png$/
      new_content.update(*@data_store.read(uid))
      new_content.data.should == 'eggheads'
    end

    it "should allow for setting the path manually" do
      uid = @data_store.write(content, path: 'hello/there')
      uid.should == 'hello/there'
      new_content.update(*@data_store.read(uid))
      new_content.data.should == 'eggheads'
    end

    if enabled # Fog.mock! doesn't act consistently here
      it "should reset the connection and try again if Fog throws a socket EOFError" do
        @data_store.storage.should_receive(:put_object).exactly(:once).and_raise(Excon::Errors::SocketError.new(EOFError.new))
        @data_store.storage.should_receive(:put_object).with(BUCKET_NAME, anything, anything, hash_including)
        @data_store.write(content)
      end

      it "should just let it raise if Fog throws a socket EOFError again" do
        @data_store.storage.should_receive(:put_object).and_raise(Excon::Errors::SocketError.new(EOFError.new))
        @data_store.storage.should_receive(:put_object).and_raise(Excon::Errors::SocketError.new(EOFError.new))
        expect{
          @data_store.write(content)
        }.to raise_error(Excon::Errors::SocketError)
      end
    end
  end

  describe "not configuring stuff properly" do
    it "should require a bucket name on write" do
      @data_store.bucket_name = nil
      proc{ @data_store.write(content) }.should raise_error(Dragonfly::FogDataStore::NotConfigured)
    end

    it "should require an rackspace_api_key on write" do
      @data_store.rackspace_api_key = nil
      proc{ @data_store.write(content) }.should raise_error(Dragonfly::FogDataStore::NotConfigured)
    end

    it "should require a secret access key on write" do
      @data_store.rackspace_username = nil
      proc{ @data_store.write(content) }.should raise_error(Dragonfly::FogDataStore::NotConfigured)
    end

    it "should require a bucket name on read" do
      @data_store.bucket_name = nil
      proc{ @data_store.read('asdf') }.should raise_error(Dragonfly::FogDataStore::NotConfigured)
    end

    it "should require an rackspace_api_key on read" do
      @data_store.rackspace_api_key = nil
      proc{ @data_store.read('asdf') }.should raise_error(Dragonfly::FogDataStore::NotConfigured)
    end

    it "should require a secret access key on read" do
      @data_store.rackspace_username = nil
      proc{ @data_store.read('asdf') }.should raise_error(Dragonfly::FogDataStore::NotConfigured)
    end

    if !enabled #this will fail since the specs are not running on an ec2 instance with an iam role defined
      it 'should allow missing secret key and access key on write if iam profiles are allowed' do
        # This is slightly brittle but it's annoying waiting for fog doing stuff
        @data_store.storage.stub(get_bucket_location: nil, put_object: nil)

        @data_store.rackspace_username = nil
        @data_store.rackspace_api_key = nil
        expect{ @data_store.write(content) }.not_to raise_error
      end
    end

  end

  describe "autocreating the bucket" do
    it "should create the bucket on write if it doesn't exist" do
      @data_store.bucket_name = "dragonfly-test-blah-blah-#{rand(100000000)}"
      @data_store.write(content)
    end

    it "should not try to create the bucket on read if it doesn't exist" do
      @data_store.bucket_name = "dragonfly-test-blah-blah-#{rand(100000000)}"
      @data_store.send(:storage).should_not_receive(:put_bucket)
      @data_store.read("gungle").should be_nil
    end
  end

  describe "headers" do
    before(:each) do
      @data_store.storage_headers = {'x-amz-foo' => 'biscuithead'}
    end

    it "should allow configuring globally" do
      @data_store.storage.should_receive(:put_object).with(BUCKET_NAME, anything, anything,
        hash_including('x-amz-foo' => 'biscuithead')
      )
      @data_store.write(content)
    end

    it "should allow adding per-store" do
      @data_store.storage.should_receive(:put_object).with(BUCKET_NAME, anything, anything,
        hash_including('x-amz-foo' => 'biscuithead', 'hello' => 'there')
      )
      @data_store.write(content, headers: {'hello' => 'there'})
    end

    it "should let the per-store one take precedence" do
      @data_store.storage.should_receive(:put_object).with(BUCKET_NAME, anything, anything,
        hash_including('x-amz-foo' => 'override!')
      )
      @data_store.write(content, headers: {'x-amz-foo' => 'override!'})
    end

    it "should write setting the content type" do
      @data_store.storage.should_receive(:put_object) do |_, __, ___, headers|
        headers['Content-Type'].should == 'image/png'
      end
      content.name = 'egg.png'
      @data_store.write(content)
    end

    it "allow overriding the content type" do
      @data_store.storage.should_receive(:put_object) do |_, __, ___, headers|
        headers['Content-Type'].should == 'text/plain'
      end
      content.name = 'egg.png'
      @data_store.write(content, headers: {'Content-Type' => 'text/plain'})
    end
  end

  describe "meta" do
    it "uses the x-amz-meta-json header for meta" do
      uid = @data_store.write(content, headers: {'x-amz-meta-json' => Dragonfly::Serializer.json_encode({'potato' => 44})})
      c, meta = @data_store.read(uid)
      meta['potato'].should == 44
    end

    it "works with the deprecated x-amz-meta-extra header (but stringifies its keys)" do
      uid = @data_store.write(content, headers: {
        'x-amz-meta-extra' => Dragonfly::Serializer.marshal_b64_encode(some: 'meta', wo: 4),
        'x-amz-meta-json' => nil
      })
      c, meta = @data_store.read(uid)
      meta['some'].should == 'meta'
      meta['wo'].should == 4
    end
  end

end
