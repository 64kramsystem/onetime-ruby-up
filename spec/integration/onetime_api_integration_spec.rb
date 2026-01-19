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

    it 'creates and retrieves a secret successfully' do
      secret_value = "Test secret retrieval - #{Time.now.to_i}"

      # Create a secret
      share_response = api.post('/secret/conceal', secret: secret_value)
      secret_key = share_response['record']['secret']['key']

      expect(secret_key).not_to be_nil

      sleep 1 # Rate limiting

      # Retrieve the secret
      reveal_response = api.post("/secret/#{secret_key}/reveal", continue: true)

      expect(reveal_response).not_to be_nil
      expect(reveal_response['success']).to be true
      expect(reveal_response['record']['secret_value']).to eq(secret_value)
      expect(reveal_response['details']['show_secret']).to be true
      expect(reveal_response['record']['state']).to eq('received')

      sleep 1 # Rate limiting
    end

    it 'retrieves a secret only once (one-time use)' do
      secret_value = "One time only - #{Time.now.to_i}"

      # Create a secret
      share_response = api.post('/secret/conceal', secret: secret_value)
      secret_key = share_response['record']['secret']['key']

      sleep 1 # Rate limiting

      # First retrieval should succeed
      first_reveal = api.post("/secret/#{secret_key}/reveal", continue: true)
      expect(first_reveal['record']['secret_value']).to eq(secret_value)

      sleep 1 # Rate limiting

      # Second retrieval should fail (secret already consumed)
      api.post("/secret/#{secret_key}/reveal", continue: true)
      expect(api.response.code).not_to eq(200)

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

    it 'creates and retrieves a secret with passphrase' do
      secret_value = "Passphrase protected - #{Time.now.to_i}"
      passphrase = "secure-pass-#{rand(10000)}"

      # Create a secret with passphrase
      share_response = api.post('/secret/conceal', secret: secret_value, passphrase: passphrase)
      secret_key = share_response['record']['secret']['key']

      expect(share_response['record']['secret']['has_passphrase']).to be true

      sleep 1 # Rate limiting

      # Retrieve with correct passphrase
      reveal_response = api.post("/secret/#{secret_key}/reveal", passphrase: passphrase, continue: true)

      expect(reveal_response).not_to be_nil
      expect(reveal_response['success']).to be true
      expect(reveal_response['record']['secret_value']).to eq(secret_value)
      expect(reveal_response['details']['correct_passphrase']).to be true
      expect(reveal_response['details']['show_secret']).to be true

      sleep 1 # Rate limiting
    end

    it 'fails to retrieve secret with wrong passphrase' do
      secret_value = "Wrong passphrase test - #{Time.now.to_i}"
      passphrase = "correct-pass-#{rand(10000)}"

      # Create a secret with passphrase
      share_response = api.post('/secret/conceal', secret: secret_value, passphrase: passphrase)
      secret_key = share_response['record']['secret']['key']

      sleep 1 # Rate limiting

      # Try to retrieve with wrong passphrase
      reveal_response = api.post("/secret/#{secret_key}/reveal", passphrase: "wrong-password", continue: true)

      # The API should return a response indicating incorrect passphrase
      expect(reveal_response).not_to be_nil
      if reveal_response['details']
        expect(reveal_response['details']['correct_passphrase']).to be false
        expect(reveal_response['details']['show_secret']).to be false
      end
      # Secret value should not be present
      expect(reveal_response.dig('record', 'secret_value')).to be_nil

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

    it 'creates and retrieves a secret with TTL' do
      secret_value = "TTL test secret - #{Time.now.to_i}"
      ttl = 7200 # 2 hours

      # Create a secret with TTL
      share_response = api.post('/secret/conceal', secret: secret_value, ttl: ttl)
      secret_key = share_response['record']['secret']['key']

      expect(share_response['record']['metadata']['secret_ttl']).to eq(ttl)

      sleep 1 # Rate limiting

      # Retrieve the secret before TTL expires
      reveal_response = api.post("/secret/#{secret_key}/reveal", continue: true)

      expect(reveal_response).not_to be_nil
      expect(reveal_response['success']).to be true
      expect(reveal_response['record']['secret_value']).to eq(secret_value)
      expect(reveal_response['record']['secret_ttl']).to eq(ttl.to_s)

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
