require 'spec_helper'

RSpec.describe Onetime::API do
  describe 'VERSION' do
    it 'reads version from VERSION file' do
      expect(Onetime::API::VERSION.to_s).to match(/^\d+\.\d+\.\d+$/)
    end

    it 'returns version as string' do
      expect(Onetime::API::VERSION.to_s).to be_a(String)
    end

    it 'returns version as array' do
      version_array = Onetime::API::VERSION.to_a
      expect(version_array).to be_an(Array)
      expect(version_array.length).to eq(3)
    end

    it 'reports prerelease status' do
      expect(Onetime::API::VERSION.prerelease?).to be false
    end
  end

  describe 'initialization' do
    context 'with custid and apikey' do
      let(:custid) { 'test@example.com' }
      let(:apikey) { 'testapikey123' }

      it 'creates an authenticated API instance' do
        api = Onetime::API.new(custid, apikey)
        expect(api.custid).to eq(custid)
        expect(api.key).to eq(apikey)
        expect(api.anonymous).to be false
      end
    end

    context 'without credentials' do
      it 'creates an anonymous API instance' do
        api = Onetime::API.new
        expect(api.anonymous).to be true
      end
    end

    context 'with only custid' do
      it 'raises an error' do
        expect {
          Onetime::API.new('test@example.com', nil)
        }.to raise_error(RuntimeError, /You provided a custid without an apikey/)
      end
    end

    context 'with only apikey' do
      it 'raises an error' do
        expect {
          Onetime::API.new(nil, 'testapikey')
        }.to raise_error(RuntimeError, /You provided an apikey without a custid/)
      end
    end

    context 'with environment variables' do
      before do
        ENV['ONETIME_CUSTID'] = 'env_custid'
        ENV['ONETIME_APIKEY'] = 'env_apikey'
      end

      after do
        ENV.delete('ONETIME_CUSTID')
        ENV.delete('ONETIME_APIKEY')
      end

      it 'uses environment variables when no parameters provided' do
        api = Onetime::API.new
        expect(api.custid).to eq('env_custid')
        expect(api.key).to eq('env_apikey')
        expect(api.anonymous).to be false
      end
    end

    context 'with custom host' do
      before do
        ENV['ONETIME_HOST'] = 'https://custom.example.com/api'
      end

      after do
        ENV.delete('ONETIME_HOST')
        Onetime::API.base_uri('https://onetimesecret.com/api')
      end

      it 'uses custom host from environment variable' do
        Onetime::API.new
        expect(Onetime::API.base_uri).to eq('https://custom.example.com/api')
      end
    end

    context 'with custom apiversion' do
      it 'uses provided apiversion' do
        api = Onetime::API.new(nil, nil, apiversion: 2)
        expect(api.apiversion).to eq(2)
      end

      it 'defaults to version 1' do
        api = Onetime::API.new
        expect(api.apiversion).to eq(1)
      end
    end
  end

  describe '#api_path' do
    let(:api) { Onetime::API.new }

    it 'constructs path with version prefix' do
      path = api.api_path('status')
      expect(path).to eq('/v1/status')
    end

    it 'handles multiple path segments' do
      path = api.api_path('secret', 'abc123')
      expect(path).to eq('/v1/secret/abc123')
    end

    it 'removes duplicate slashes' do
      path = api.api_path('/status/')
      expect(path).to eq('/v1/status/')
    end
  end

  describe '#get' do
    let(:custid) { 'test@example.com' }
    let(:apikey) { 'testapikey123' }
    let(:api) { Onetime::API.new(custid, apikey) }

    context 'with authenticated API' do
      it 'makes a GET request' do
        stub_request(:get, "https://onetimesecret.com/api/v1/status")
          .to_return(
            status: 200,
            body: '{"status":"nominal"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = api.get('/status')
        expect(response['status']).to eq('nominal')
      end

      it 'sends query parameters' do
        stub_request(:get, "https://onetimesecret.com/api/v1/test")
          .with(query: { 'foo' => 'bar' })
          .to_return(
            status: 200,
            body: '{"result":"success"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = api.get('/test', foo: 'bar')
        expect(response['result']).to eq('success')
      end

      it 'sends Basic Auth credentials' do
        stub = stub_request(:get, "https://onetimesecret.com/api/v1/status")
          .with(
            basic_auth: [custid, apikey]
          )
          .to_return(
            status: 200,
            body: '{"status":"nominal"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        api.get('/status')
        expect(stub).to have_been_requested
      end
    end

    context 'with anonymous API' do
      let(:anonymous_api) { Onetime::API.new }

      it 'makes requests without authentication' do
        stub = stub_request(:get, "https://onetimesecret.com/api/v1/status")
          .to_return(
            status: 200,
            body: '{"status":"nominal"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = anonymous_api.get('/status')
        expect(response['status']).to eq('nominal')
        expect(stub).to have_been_requested
      end
    end
  end

  describe '#post' do
    let(:custid) { 'test@example.com' }
    let(:apikey) { 'testapikey123' }
    let(:api) { Onetime::API.new(custid, apikey) }

    context 'share endpoint' do
      it 'makes a POST request with form-encoded body' do
        stub_request(:post, "https://onetimesecret.com/api/v1/share")
          .with(
            body: { 'secret' => 'mysecret', 'passphrase' => 'mypass' }
          )
          .to_return(
            status: 200,
            body: '{"secret_key":"abc123","metadata_key":"def456"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = api.post('/share', secret: 'mysecret', passphrase: 'mypass')
        expect(response['secret_key']).to eq('abc123')
        expect(response['metadata_key']).to eq('def456')
      end

      it 'handles TTL parameter' do
        stub_request(:post, "https://onetimesecret.com/api/v1/share")
          .with(
            body: { 'secret' => 'mysecret', 'ttl' => '3600' }
          )
          .to_return(
            status: 200,
            body: '{"secret_key":"abc123","metadata_key":"def456","ttl":3600}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = api.post('/share', secret: 'mysecret', ttl: 3600)
        expect(response['ttl']).to eq(3600)
      end

      it 'handles recipient parameter as array' do
        stub_request(:post, "https://onetimesecret.com/api/v1/share")
          .with(
            body: hash_including('secret' => 'mysecret')
          )
          .to_return(
            status: 200,
            body: '{"secret_key":"abc123","metadata_key":"def456","recipient":["user@example.com"]}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = api.post('/share', secret: 'mysecret', recipient: ['user@example.com'])
        expect(response['recipient']).to eq(['user@example.com'])
      end

      it 'sends Basic Auth credentials' do
        stub = stub_request(:post, "https://onetimesecret.com/api/v1/share")
          .with(
            basic_auth: [custid, apikey]
          )
          .to_return(
            status: 200,
            body: '{"secret_key":"abc123","metadata_key":"def456"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        api.post('/share', secret: 'mysecret')
        expect(stub).to have_been_requested
      end
    end

    context 'secret endpoint' do
      it 'retrieves a secret by key' do
        stub_request(:post, "https://onetimesecret.com/api/v1/secret/abc123")
          .to_return(
            status: 200,
            body: '{"value":"mysecret","secret_key":"abc123"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = api.post('/secret/abc123')
        expect(response['value']).to eq('mysecret')
        expect(response['secret_key']).to eq('abc123')
      end

      it 'retrieves a secret with passphrase' do
        stub_request(:post, "https://onetimesecret.com/api/v1/secret/abc123")
          .with(
            body: { 'passphrase' => 'mypass' }
          )
          .to_return(
            status: 200,
            body: '{"value":"mysecret","secret_key":"abc123"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = api.post('/secret/abc123', passphrase: 'mypass')
        expect(response['value']).to eq('mysecret')
      end
    end

    context 'metadata endpoint' do
      it 'retrieves metadata by key' do
        stub_request(:post, "https://onetimesecret.com/api/v1/metadata/def456")
          .to_return(
            status: 200,
            body: '{"secret_key":"abc123","metadata_key":"def456","state":"viewed"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = api.post('/metadata/def456')
        expect(response['secret_key']).to eq('abc123')
        expect(response['metadata_key']).to eq('def456')
        expect(response['state']).to eq('viewed')
      end
    end

    context 'generate endpoint' do
      it 'generates a random secret' do
        stub_request(:post, "https://onetimesecret.com/api/v1/generate")
          .to_return(
            status: 200,
            body: '{"value":"randomvalue123","secret_key":"abc123","metadata_key":"def456"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = api.post('/generate')
        expect(response['value']).to eq('randomvalue123')
        expect(response['secret_key']).to eq('abc123')
        expect(response['metadata_key']).to eq('def456')
      end

      it 'generates with TTL and passphrase' do
        stub_request(:post, "https://onetimesecret.com/api/v1/generate")
          .with(
            body: { 'ttl' => '7200', 'passphrase' => 'mypass' }
          )
          .to_return(
            status: 200,
            body: '{"value":"randomvalue123","secret_key":"abc123","ttl":7200}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = api.post('/generate', ttl: 7200, passphrase: 'mypass')
        expect(response['value']).to eq('randomvalue123')
        expect(response['ttl']).to eq(7200)
      end
    end
  end

  describe '.indifferent_params' do
    it 'converts hash keys to allow symbol or string access' do
      params = { 'foo' => 'bar', 'nested' => { 'key' => 'value' } }
      result = Onetime::API.indifferent_params(params)

      expect(result[:foo]).to eq('bar')
      expect(result['foo']).to eq('bar')
      expect(result[:nested][:key]).to eq('value')
    end

    it 'handles arrays of hashes' do
      params = [{ 'foo' => 'bar' }, { 'baz' => 'qux' }]
      result = Onetime::API.indifferent_params(params)

      expect(result[0][:foo]).to eq('bar')
      expect(result[1][:baz]).to eq('qux')
    end
  end

  describe '.web_path' do
    it 'constructs web path' do
      path = Onetime::API.web_path('secret', 'abc123')
      expect(path).to eq('/secret/abc123')
    end

    it 'removes duplicate slashes' do
      path = Onetime::API.web_path('/secret/', '/abc123')
      expect(path).to eq('/secret/abc123')
    end
  end

  describe '.web_uri' do
    it 'constructs full web URI' do
      uri = Onetime::API.web_uri('secret', 'abc123')
      expect(uri.to_s).to eq('https://onetimesecret.com/secret/abc123')
    end
  end

  describe 'OT alias' do
    it 'provides OT as an alias for Onetime' do
      expect(OT).to eq(Onetime)
    end

    it 'allows OT::API usage' do
      api = OT::API.new
      expect(api).to be_a(Onetime::API)
    end
  end

  describe 'error handling' do
    let(:api) { Onetime::API.new }

    it 'handles 404 Not Found responses' do
      stub_request(:post, "https://onetimesecret.com/api/v1/secret/invalid")
        .to_return(
          status: 404,
          body: '{"message":"Unknown secret"}',
          headers: { 'Content-Type' => 'application/json' }
        )

      response = api.post('/secret/invalid')
      expect(response['message']).to eq('Unknown secret')
      expect(api.response.code).to eq(404)
    end

    it 'handles 401 Unauthorized responses' do
      stub_request(:get, "https://onetimesecret.com/api/v1/status")
        .to_return(
          status: 401,
          body: '{"message":"Unauthorized"}',
          headers: { 'Content-Type' => 'application/json' }
        )

      response = api.get('/status')
      expect(response['message']).to eq('Unauthorized')
      expect(api.response.code).to eq(401)
    end

    it 'handles 400 Bad Request responses' do
      stub_request(:post, "https://onetimesecret.com/api/v1/share")
        .to_return(
          status: 400,
          body: '{"message":"Bad Request"}',
          headers: { 'Content-Type' => 'application/json' }
        )

      response = api.post('/share')
      expect(response['message']).to eq('Bad Request')
      expect(api.response.code).to eq(400)
    end
  end

  describe 'HTTP headers' do
    let(:api) { Onetime::API.new }

    it 'sends X-Onetime-Client header' do
      stub = stub_request(:get, "https://onetimesecret.com/api/v1/status")
        .with(
          headers: { 'X-Onetime-Client' => /ruby:/ }
        )
        .to_return(
          status: 200,
          body: '{"status":"nominal"}',
          headers: { 'Content-Type' => 'application/json' }
        )

      api.get('/status')
      expect(stub).to have_been_requested
    end

    it 'includes version in X-Onetime-Client header' do
      stub = stub_request(:post, "https://onetimesecret.com/api/v1/share")
        .with(
          headers: {
            'X-Onetime-Client' => "ruby: #{RUBY_VERSION}/#{Onetime::API::VERSION}"
          }
        )
        .to_return(
          status: 200,
          body: '{"secret_key":"abc123"}',
          headers: { 'Content-Type' => 'application/json' }
        )

      api.post('/share', secret: 'test')
      expect(stub).to have_been_requested
    end
  end

  describe 'response parsing' do
    let(:api) { Onetime::API.new }

    it 'parses JSON responses' do
      stub_request(:get, "https://onetimesecret.com/api/v1/status")
        .to_return(
          status: 200,
          body: '{"status":"nominal","version":"1.0"}',
          headers: { 'Content-Type' => 'application/json' }
        )

      response = api.get('/status')
      expect(response).to be_a(Hash)
      expect(response['status']).to eq('nominal')
      expect(response['version']).to eq('1.0')
    end

    it 'makes responses accessible with symbols via indifferent_params' do
      stub_request(:get, "https://onetimesecret.com/api/v1/status")
        .to_return(
          status: 200,
          body: '{"status":"nominal"}',
          headers: { 'Content-Type' => 'application/json' }
        )

      response = api.get('/status')
      expect(response[:status]).to eq('nominal')
      expect(response['status']).to eq('nominal')
    end

    it 'handles nested JSON objects' do
      stub_request(:post, "https://onetimesecret.com/api/v1/share")
        .to_return(
          status: 200,
          body: '{"secret_key":"abc123","metadata":{"created":"2023-01-01"}}',
          headers: { 'Content-Type' => 'application/json' }
        )

      response = api.post('/share', secret: 'test')
      expect(response[:metadata][:created]).to eq('2023-01-01')
    end
  end

  describe 'API version support' do
    it 'uses apiversion in path construction' do
      api = Onetime::API.new(nil, nil, apiversion: 2)
      path = api.api_path('status')
      expect(path).to eq('/v2/status')
    end

    it 'can make requests with different API versions' do
      api = Onetime::API.new(nil, nil, apiversion: 2)

      stub_request(:get, "https://onetimesecret.com/api/v2/status")
        .to_return(
          status: 200,
          body: '{"status":"nominal"}',
          headers: { 'Content-Type' => 'application/json' }
        )

      response = api.get('/status')
      expect(response['status']).to eq('nominal')
    end
  end
end
