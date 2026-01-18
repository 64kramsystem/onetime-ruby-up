require 'spec_helper'

RSpec.describe Onetime::API do
  describe 'VERSION' do
    it 'is defined as a string constant' do
      expect(Onetime::VERSION).to match(/^\d+\.\d+\.\d+$/)
    end

    it 'returns version as string' do
      expect(Onetime::VERSION).to be_a(String)
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
        Onetime::API.base_uri('https://eu.onetimesecret.com/api')
      end

      it 'uses custom host from environment variable' do
        Onetime::API.new
        expect(Onetime::API.base_uri).to eq('https://custom.example.com/api')
      end
    end

  end

  describe '#api_path' do
    let(:api) { Onetime::API.new }

    it 'constructs path with version prefix' do
      path = api.api_path('status')
      expect(path).to eq('/v2/status')
    end

    it 'handles multiple path segments' do
      path = api.api_path('secret', 'abc123')
      expect(path).to eq('/v2/secret/abc123')
    end

    it 'removes duplicate slashes' do
      path = api.api_path('/status/')
      expect(path).to eq('/v2/status/')
    end
  end

  describe '#get' do
    let(:custid) { 'test@example.com' }
    let(:apikey) { 'testapikey123' }
    let(:api) { Onetime::API.new(custid, apikey) }

    context 'with authenticated API' do
      it 'makes a GET request' do
        stub_request(:get, "https://eu.onetimesecret.com/api/v2/status")
          .to_return(
            status: 200,
            body: '{"status":"nominal"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = api.get('/status')
        expect(response['status']).to eq('nominal')
      end

      it 'sends query parameters' do
        stub_request(:get, "https://eu.onetimesecret.com/api/v2/test")
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
        stub = stub_request(:get, "https://eu.onetimesecret.com/api/v2/status")
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
        stub = stub_request(:get, "https://eu.onetimesecret.com/api/v2/status")
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

    context 'share endpoint (V2 /secret/conceal)' do
      it 'makes a POST request with JSON body' do
        stub_request(:post, "https://eu.onetimesecret.com/api/v2/secret/conceal")
          .with(
            body: { 'secret' => { 'secret' => 'mysecret', 'passphrase' => 'mypass' } }.to_json,
            headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
          )
          .to_return(
            status: 200,
            body: '{"record":{"secret":{"shortkey":"abc123","key":"abc123def456ghi789"},"metadata":{"key":"def456"}},"details":{}}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = api.post('/secret/conceal', secret: 'mysecret', passphrase: 'mypass')
        expect(response['record']['secret']['key']).to eq('abc123def456ghi789')
        expect(response['record']['metadata']['key']).to eq('def456')
      end

      it 'handles TTL parameter' do
        stub_request(:post, "https://eu.onetimesecret.com/api/v2/secret/conceal")
          .with(
            body: { 'secret' => { 'secret' => 'mysecret', 'ttl' => 3600 } }.to_json,
            headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
          )
          .to_return(
            status: 200,
            body: '{"record":{"secret":{"shortkey":"abc123","key":"abc123def456ghi789"},"metadata":{"key":"def456","secret_ttl":3600}},"details":{}}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = api.post('/secret/conceal', secret: 'mysecret', ttl: 3600)
        expect(response['record']['metadata']['secret_ttl']).to eq(3600)
      end

      it 'handles recipient parameter as array' do
        stub_request(:post, "https://eu.onetimesecret.com/api/v2/secret/conceal")
          .with(
            body: /"secret":\{.*"secret":"mysecret".*\}/,
            headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
          )
          .to_return(
            status: 200,
            body: '{"record":{"secret":{"shortkey":"abc123","key":"abc123def456ghi789"},"metadata":{"key":"def456"}},"details":{"recipient":["user@example.com"]}}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = api.post('/secret/conceal', secret: 'mysecret', recipient: ['user@example.com'])
        expect(response['details']['recipient']).to eq(['user@example.com'])
      end

      it 'sends Basic Auth credentials' do
        stub = stub_request(:post, "https://eu.onetimesecret.com/api/v2/secret/conceal")
          .with(
            basic_auth: [custid, apikey],
            headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
          )
          .to_return(
            status: 200,
            body: '{"record":{"secret":{"shortkey":"abc123","key":"abc123def456ghi789"},"metadata":{"key":"def456"}},"details":{}}',
            headers: { 'Content-Type' => 'application/json' }
          )

        api.post('/secret/conceal', secret: 'mysecret')
        expect(stub).to have_been_requested
      end
    end

    context 'secret endpoint (V2 /secret/:key/reveal)' do
      it 'retrieves a secret by key' do
        stub_request(:post, "https://eu.onetimesecret.com/api/v2/secret/abc123/reveal")
          .with(
            headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
          )
          .to_return(
            status: 200,
            body: '{"record":{"secret":{"shortkey":"abc123","key":"abc123def456ghi789","value":"mysecret"},"metadata":{}},"details":{}}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = api.post('/secret/abc123/reveal')
        expect(response['record']['secret']['value']).to eq('mysecret')
        expect(response['record']['secret']['key']).to eq('abc123def456ghi789')
      end

      it 'retrieves a secret with passphrase' do
        stub_request(:post, "https://eu.onetimesecret.com/api/v2/secret/abc123/reveal")
          .with(
            body: { 'passphrase' => 'mypass' }.to_json,
            headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
          )
          .to_return(
            status: 200,
            body: '{"record":{"secret":{"shortkey":"abc123","key":"abc123def456ghi789","value":"mysecret"},"metadata":{}},"details":{}}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = api.post('/secret/abc123/reveal', passphrase: 'mypass')
        expect(response['record']['secret']['value']).to eq('mysecret')
      end
    end

    context 'receipt endpoint' do
      it 'retrieves receipt by key (non-normalized response)' do
        stub_request(:get, "https://eu.onetimesecret.com/api/v2/receipt/def456")
          .to_return(
            status: 200,
            body: '{"secret_key":"abc123def456ghi789","metadata_key":"def456","state":"viewed"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = api.get('/receipt/def456')
        expect(response['secret_key']).to eq('abc123def456ghi789')
        expect(response['metadata_key']).to eq('def456')
        expect(response['state']).to eq('viewed')
      end
    end

    context 'generate endpoint (V2 /secret/generate)' do
      it 'generates a random secret' do
        stub_request(:post, "https://eu.onetimesecret.com/api/v2/secret/generate")
          .with(
            headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
          )
          .to_return(
            status: 200,
            body: '{"record":{"secret":{"shortkey":"abc123","key":"abc123def456ghi789","value":"randomvalue123"},"metadata":{"key":"def456"}},"details":{}}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = api.post('/secret/generate')
        expect(response['record']['secret']['value']).to eq('randomvalue123')
        expect(response['record']['secret']['key']).to eq('abc123def456ghi789')
        expect(response['record']['metadata']['key']).to eq('def456')
      end

      it 'generates with TTL and passphrase' do
        stub_request(:post, "https://eu.onetimesecret.com/api/v2/secret/generate")
          .with(
            body: { 'secret' => { 'ttl' => 7200, 'passphrase' => 'mypass' } }.to_json,
            headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
          )
          .to_return(
            status: 200,
            body: '{"record":{"secret":{"shortkey":"abc123","key":"abc123def456ghi789","value":"randomvalue123"},"metadata":{"key":"def456","secret_ttl":7200}},"details":{}}',
            headers: { 'Content-Type' => 'application/json' }
          )

        response = api.post('/secret/generate', ttl: 7200, passphrase: 'mypass')
        expect(response['record']['secret']['value']).to eq('randomvalue123')
        expect(response['record']['metadata']['secret_ttl']).to eq(7200)
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
      expect(uri.to_s).to eq('https://eu.onetimesecret.com/secret/abc123')
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
      stub_request(:post, "https://eu.onetimesecret.com/api/v2/secret/invalid/reveal")
        .to_return(
          status: 404,
          body: '{"message":"Unknown secret"}',
          headers: { 'Content-Type' => 'application/json' }
        )

      response = api.post('/secret/invalid/reveal')
      expect(response['message']).to eq('Unknown secret')
      expect(api.response.code).to eq(404)
    end

    it 'handles 401 Unauthorized responses' do
      stub_request(:get, "https://eu.onetimesecret.com/api/v2/status")
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
      stub_request(:post, "https://eu.onetimesecret.com/api/v2/secret/conceal")
        .to_return(
          status: 400,
          body: '{"message":"Bad Request"}',
          headers: { 'Content-Type' => 'application/json' }
        )

      response = api.post('/secret/conceal')
      expect(response['message']).to eq('Bad Request')
      expect(api.response.code).to eq(400)
    end
  end

  describe 'HTTP headers' do
    let(:api) { Onetime::API.new }

    it 'sends X-Onetime-Client header' do
      stub = stub_request(:get, "https://eu.onetimesecret.com/api/v2/status")
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

    it 'includes version in X-Onetime-Client header and JSON headers for POST' do
      stub = stub_request(:post, "https://eu.onetimesecret.com/api/v2/secret/conceal")
        .with(
          headers: {
            'X-Onetime-Client' => "ruby: #{RUBY_VERSION}/#{Onetime::VERSION}",
            'Content-Type' => 'application/json',
            'Accept' => 'application/json'
          }
        )
        .to_return(
          status: 200,
          body: '{"record":{"secret":{"shortkey":"abc123","key":"abc123def456ghi789"},"metadata":{}},"details":{}}',
          headers: { 'Content-Type' => 'application/json' }
        )

      api.post('/secret/conceal', secret: 'test')
      expect(stub).to have_been_requested
    end
  end

  describe 'response parsing' do
    let(:api) { Onetime::API.new }

    it 'parses JSON responses' do
      stub_request(:get, "https://eu.onetimesecret.com/api/v2/status")
        .to_return(
          status: 200,
          body: '{"status":"nominal","version":"2.0"}',
          headers: { 'Content-Type' => 'application/json' }
        )

      response = api.get('/status')
      expect(response).to be_a(Hash)
      expect(response['status']).to eq('nominal')
      expect(response['version']).to eq('2.0')
    end

    it 'makes responses accessible with symbols via indifferent_params' do
      stub_request(:get, "https://eu.onetimesecret.com/api/v2/status")
        .to_return(
          status: 200,
          body: '{"status":"nominal"}',
          headers: { 'Content-Type' => 'application/json' }
        )

      response = api.get('/status')
      expect(response[:status]).to eq('nominal')
      expect(response['status']).to eq('nominal')
    end

    it 'returns raw V2 API responses' do
      stub_request(:post, "https://eu.onetimesecret.com/api/v2/secret/conceal")
        .to_return(
          status: 200,
          body: '{"record":{"secret":{"shortkey":"abc123","key":"abc123def456ghi789"},"metadata":{"key":"def456","secret_ttl":3600}},"details":{"recipient":[]}}',
          headers: { 'Content-Type' => 'application/json' }
        )

      response = api.post('/secret/conceal', secret: 'test')
      expect(response['record']['secret']['key']).to eq('abc123def456ghi789')
      expect(response['record']['metadata']['key']).to eq('def456')
      expect(response['record']['metadata']['secret_ttl']).to eq(3600)
      expect(response['details']['recipient']).to eq([])
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

      stub_request(:get, "https://eu.onetimesecret.com/api/v2/status")
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
