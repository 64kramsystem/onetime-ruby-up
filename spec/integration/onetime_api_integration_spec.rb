require 'spec_helper'

RSpec.describe 'Onetime::API Integration Tests', :integration do
  let(:api) do
    custid = ENV['ONETIME_CUSTID']
    apikey = ENV['ONETIME_APIKEY']

    if custid && apikey
      Onetime::API.new(custid, apikey)
    else
      # Use anonymous API if credentials not provided
      Onetime::API.new
    end
  end

  describe 'Secret workflow: create and retrieve' do
    it 'creates a secret and retrieves it successfully' do
      secret_value = "Integration test secret - #{Time.now.to_i}"

      # Step 1: Share/create a secret
      share_response = api.post('/share', secret: secret_value)

      expect(share_response).not_to be_nil
      expect(share_response['secret_key']).not_to be_nil
      expect(share_response['metadata_key']).not_to be_nil

      secret_key = share_response['secret_key']

      # Step 2: Retrieve the secret
      secret_response = api.post("/secret/#{secret_key}")

      expect(secret_response).not_to be_nil
      expect(secret_response['value']).to eq(secret_value)
      expect(secret_response['secret_key']).to eq(secret_key)

      # Step 3: Verify secret is burned (can't retrieve again)
      burned_response = api.post("/secret/#{secret_key}")

      # The secret should no longer be available
      expect(burned_response['value']).to be_nil
    end

    it 'creates a secret with passphrase and retrieves it' do
      secret_value = "Secret with passphrase - #{Time.now.to_i}"
      passphrase = "my-secure-passphrase-#{rand(1000)}"

      # Step 1: Share/create a secret with passphrase
      share_response = api.post('/share', secret: secret_value, passphrase: passphrase)

      expect(share_response).not_to be_nil
      expect(share_response['secret_key']).not_to be_nil

      secret_key = share_response['secret_key']

      # Step 2: Try to retrieve without passphrase (should fail)
      no_pass_response = api.post("/secret/#{secret_key}")
      expect(no_pass_response['value']).to be_nil

      # Step 3: Retrieve with correct passphrase
      secret_response = api.post("/secret/#{secret_key}", passphrase: passphrase)

      expect(secret_response).not_to be_nil
      expect(secret_response['value']).to eq(secret_value)
    end

    it 'creates a secret with TTL' do
      secret_value = "Secret with TTL - #{Time.now.to_i}"
      ttl = 3600 # 1 hour

      # Share/create a secret with TTL
      share_response = api.post('/share', secret: secret_value, ttl: ttl)

      expect(share_response).not_to be_nil
      expect(share_response['secret_key']).not_to be_nil
      expect(share_response['ttl']).to eq(ttl)

      secret_key = share_response['secret_key']

      # Retrieve the secret to verify it works
      secret_response = api.post("/secret/#{secret_key}")

      expect(secret_response).not_to be_nil
      expect(secret_response['value']).to eq(secret_value)
    end
  end

  describe 'Metadata workflow' do
    it 'creates a secret and retrieves its metadata' do
      secret_value = "Secret for metadata test - #{Time.now.to_i}"

      # Create a secret
      share_response = api.post('/share', secret: secret_value)
      metadata_key = share_response['metadata_key']

      # Retrieve metadata
      metadata_response = api.post("/metadata/#{metadata_key}")

      expect(metadata_response).not_to be_nil
      expect(metadata_response['secret_key']).to eq(share_response['secret_key'])
      expect(metadata_response['metadata_key']).to eq(metadata_key)
      # Note: Retrieving metadata changes state to 'viewed'
      expect(['new', 'viewed']).to include(metadata_response['state'])
    end

    it 'shows metadata state changes after secret is retrieved' do
      secret_value = "Secret for state test - #{Time.now.to_i}"

      # Create a secret
      share_response = api.post('/share', secret: secret_value)
      secret_key = share_response['secret_key']
      metadata_key = share_response['metadata_key']

      # Check initial state (retrieving metadata changes it to 'viewed')
      metadata_before = api.post("/metadata/#{metadata_key}")
      expect(['new', 'viewed']).to include(metadata_before['state'])

      # Retrieve the secret (burns it)
      api.post("/secret/#{secret_key}")

      # Check state after retrieval
      metadata_after = api.post("/metadata/#{metadata_key}")
      expect(metadata_after['state']).to eq('received')
    end
  end

  describe 'Generate workflow' do
    it 'generates a random secret' do
      # Generate a random secret
      generate_response = api.post('/generate')

      expect(generate_response).not_to be_nil
      expect(generate_response['value']).not_to be_nil
      expect(generate_response['secret_key']).not_to be_nil
      expect(generate_response['value'].length).to be > 0

      # Verify we can retrieve the generated secret
      secret_response = api.post("/secret/#{generate_response['secret_key']}")
      expect(secret_response['value']).to eq(generate_response['value'])
    end
  end

  describe 'Status check' do
    it 'retrieves service status' do
      status_response = api.get('/status')

      expect(status_response).not_to be_nil
      expect(status_response['status']).not_to be_nil
    end
  end
end
