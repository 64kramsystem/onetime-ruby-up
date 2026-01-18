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
    it 'creates a secret successfully' do
      secret_value = "Integration test secret - #{Time.now.to_i}"

      # Create a secret
      share_response = api.post('/secret/conceal', secret: secret_value)

      expect(share_response).not_to be_nil
      expect(share_response['record']['secret']['key']).not_to be_nil
      expect(share_response['record']['metadata']['key']).not_to be_nil

      # Verify the response has the expected structure
      expect(share_response['success']).to be true

      sleep 1 # Rate limiting
    end

    it 'creates a secret with passphrase' do
      secret_value = "Secret with passphrase - #{Time.now.to_i}"
      passphrase = "my-secure-passphrase-#{rand(1000)}"

      # Create a secret with passphrase
      share_response = api.post('/secret/conceal', secret: secret_value, passphrase: passphrase)

      expect(share_response).not_to be_nil
      expect(share_response['record']['secret']['key']).not_to be_nil
      expect(share_response['record']['metadata']['key']).not_to be_nil

      # Verify passphrase flag in original response
      expect(share_response['record']['secret']['has_passphrase']).to be true

      sleep 1 # Rate limiting
    end

    it 'creates a secret with TTL' do
      secret_value = "Secret with TTL - #{Time.now.to_i}"
      ttl = 3600 # 1 hour

      # Create a secret with TTL
      share_response = api.post('/secret/conceal', secret: secret_value, ttl: ttl)

      expect(share_response).not_to be_nil
      expect(share_response['record']['secret']['key']).not_to be_nil
      expect(share_response['record']['metadata']['secret_ttl']).to eq(ttl)

      sleep 1 # Rate limiting
    end
  end

  describe 'Metadata workflow' do
    it 'creates a secret and retrieves its metadata' do
      secret_value = "Secret for metadata test - #{Time.now.to_i}"

      # Create a secret
      share_response = api.post('/secret/conceal', secret: secret_value)
      metadata_key = share_response['record']['metadata']['key']
      secret_key = share_response['record']['secret']['key']

      # Retrieve metadata
      metadata_response = api.get("/receipt/#{metadata_key}")

      expect(metadata_response).not_to be_nil
      expect(metadata_response['record']['key']).to eq(metadata_key)
      expect(metadata_response['record']['secret_key']).not_to be_nil

      # The metadata response returns the full identifier
      expect(metadata_response['record']['secret_key']).to eq(secret_key)

      # Note: Retrieving metadata changes state to 'viewed'
      expect(['new', 'viewed']).to include(metadata_response['record']['state'])

      sleep 1 # Rate limiting
    end

    it 'checks metadata state' do
      secret_value = "Secret for state test - #{Time.now.to_i}"

      # Create a secret
      share_response = api.post('/secret/conceal', secret: secret_value)
      metadata_key = share_response['record']['metadata']['key']

      # Check initial state (retrieving metadata changes it to 'viewed')
      metadata_response = api.get("/receipt/#{metadata_key}")

      expect(metadata_response).not_to be_nil
      expect(['new', 'viewed']).to include(metadata_response['record']['state'])
      expect(metadata_response['record']['state']).not_to be_nil

      sleep 1 # Rate limiting
    end
  end

  describe 'Generate workflow' do
    it 'generates a random secret key' do
      # Generate a random secret (V2 API doesn't return the value in response)
      generate_response = api.post('/secret/generate')

      expect(generate_response).not_to be_nil
      expect(generate_response['record']['secret']['key']).not_to be_nil
      expect(generate_response['record']['metadata']['key']).not_to be_nil

      # Verify the key format (30-35 characters)
      expect(generate_response['record']['secret']['key'].length).to be_between(25, 40)

      # Verify response structure
      expect(generate_response['success']).to be true

      sleep 1 # Rate limiting
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
