require 'spec_helper'

RSpec.describe 'Onetime::API Integration Tests', :integration do
  def receipt_key(response)
    Onetime::API.receipt_key_from_response(response)
  end

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
      expect(receipt_key(share_response)).not_to be_nil

      # Verify the response has the expected structure
      expect(share_response['success']).to be true

      wait_for_rate_limit
    end

    it 'creates and retrieves a secret successfully' do
      secret_value = "Test secret retrieval - #{Time.now.to_i}"

      # Create a secret
      share_response = api.post('/secret/conceal', secret: secret_value)
      secret_key = share_response['record']['secret']['key']

      expect(secret_key).not_to be_nil

      wait_for_rate_limit

      # Retrieve the secret
      reveal_response = api.post("/secret/#{secret_key}/reveal", continue: true)

      expect(reveal_response).not_to be_nil
      expect(reveal_response['record']['secret_value']).to eq(secret_value)
      expect(reveal_response['details']['show_secret']).to be true
      expect(reveal_response['record']['state']).to eq('revealed')

      wait_for_rate_limit
    end

    it 'retrieves a secret only once (one-time use)' do
      secret_value = "One time only - #{Time.now.to_i}"

      # Create a secret
      share_response = api.post('/secret/conceal', secret: secret_value)
      secret_key = share_response['record']['secret']['key']

      wait_for_rate_limit

      # First retrieval should succeed
      first_reveal = api.post("/secret/#{secret_key}/reveal", continue: true)
      expect(first_reveal['record']['secret_value']).to eq(secret_value)

      wait_for_rate_limit

      # Second retrieval should fail (secret already consumed)
      api.post("/secret/#{secret_key}/reveal", continue: true)
      expect(api.response.code).not_to eq(200)

      wait_for_rate_limit
    end

    it 'creates a secret with passphrase' do
      secret_value = "Secret with passphrase - #{Time.now.to_i}"
      passphrase = "my-secure-passphrase-#{rand(1000)}"

      # Create a secret with passphrase
      share_response = api.post('/secret/conceal', secret: secret_value, passphrase: passphrase)

      expect(share_response).not_to be_nil
      expect(share_response['record']['secret']['key']).not_to be_nil
      expect(receipt_key(share_response)).not_to be_nil

      # Verify passphrase flag in original response
      expect(share_response.dig('record', 'secret', 'has_passphrase') || share_response.dig('record', 'receipt', 'has_passphrase')).to be true

      wait_for_rate_limit
    end

    it 'creates and retrieves a secret with passphrase' do
      secret_value = "Passphrase protected - #{Time.now.to_i}"
      passphrase = "secure-pass-#{rand(10000)}"

      # Create a secret with passphrase
      share_response = api.post('/secret/conceal', secret: secret_value, passphrase: passphrase)
      secret_key = share_response['record']['secret']['key']

      expect(share_response.dig('record', 'secret', 'has_passphrase') || share_response.dig('record', 'receipt', 'has_passphrase')).to be true

      wait_for_rate_limit

      # Retrieve with correct passphrase
      reveal_response = api.post("/secret/#{secret_key}/reveal", passphrase: passphrase, continue: true)

      expect(reveal_response).not_to be_nil
      expect(reveal_response['record']['secret_value']).to eq(secret_value)
      expect(reveal_response['details']['correct_passphrase']).to be true
      expect(reveal_response['details']['show_secret']).to be true

      wait_for_rate_limit
    end

    it 'fails to retrieve secret with wrong passphrase' do
      secret_value = "Wrong passphrase test - #{Time.now.to_i}"
      passphrase = "correct-pass-#{rand(10000)}"

      # Create a secret with passphrase
      share_response = api.post('/secret/conceal', secret: secret_value, passphrase: passphrase)
      secret_key = share_response['record']['secret']['key']

      wait_for_rate_limit

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

      wait_for_rate_limit
    end

    it 'creates a secret with TTL' do
      secret_value = "Secret with TTL - #{Time.now.to_i}"
      ttl = 3600 # 1 hour

      # Create a secret with TTL
      share_response = api.post('/secret/conceal', secret: secret_value, ttl: ttl)

      expect(share_response).not_to be_nil
      expect(share_response['record']['secret']['key']).not_to be_nil
      expect(share_response.dig('record', 'receipt', 'secret_ttl') || share_response.dig('record', 'metadata', 'secret_ttl')).to eq(ttl)

      wait_for_rate_limit
    end

    it 'creates and retrieves a secret with TTL' do
      secret_value = "TTL test secret - #{Time.now.to_i}"
      ttl = 7200 # 2 hours

      # Create a secret with TTL
      share_response = api.post('/secret/conceal', secret: secret_value, ttl: ttl)
      secret_key = share_response['record']['secret']['key']

      expect(share_response.dig('record', 'receipt', 'secret_ttl') || share_response.dig('record', 'metadata', 'secret_ttl')).to eq(ttl)

      wait_for_rate_limit

      # Retrieve the secret before TTL expires
      reveal_response = api.post("/secret/#{secret_key}/reveal", continue: true)

      expect(reveal_response).not_to be_nil
      expect(reveal_response['record']['secret_value']).to eq(secret_value)
      expect(reveal_response['record']['secret_ttl'].to_i).to eq(ttl)

      wait_for_rate_limit
    end
  end

  describe 'Metadata workflow' do
    it 'creates a secret and retrieves its metadata' do
      secret_value = "Secret for metadata test - #{Time.now.to_i}"

      # Create a secret
      share_response = api.post('/secret/conceal', secret: secret_value)
      metadata_key = receipt_key(share_response)
      secret_key = share_response['record']['secret']['key']

      # Retrieve metadata
      metadata_response = api.get("/receipt/#{metadata_key}")

      expect(metadata_response).not_to be_nil
      expect(metadata_response['record']['key']).to eq(metadata_key)
      expect(metadata_response['record']['secret_identifier']).not_to be_nil

      # The metadata response returns the full identifier
      expect(metadata_response['record']['secret_identifier']).to eq(secret_key)

      # Note: Retrieving metadata changes state to 'viewed'
      expect(['new', 'viewed']).to include(metadata_response['record']['state'])

      wait_for_rate_limit
    end

    it 'checks metadata state' do
      secret_value = "Secret for state test - #{Time.now.to_i}"

      # Create a secret
      share_response = api.post('/secret/conceal', secret: secret_value)
      metadata_key = receipt_key(share_response)

      # Check initial state (retrieving metadata changes it to 'viewed')
      metadata_response = api.get("/receipt/#{metadata_key}")

      expect(metadata_response).not_to be_nil
      expect(['new', 'viewed']).to include(metadata_response['record']['state'])
      expect(metadata_response['record']['state']).not_to be_nil

      wait_for_rate_limit
    end
  end

  describe 'Generate workflow' do
    it 'generates a random secret key' do
      # Generate a random secret (V2 API doesn't return the value in response)
      generate_response = api.post('/secret/generate')

      expect(generate_response).not_to be_nil
      expect(generate_response['record']['secret']['key']).not_to be_nil
      expect(receipt_key(generate_response)).not_to be_nil

      # Verify the key format
      expect(generate_response['record']['secret']['key']).to match(/\A[a-z0-9]{25,80}\z/)

      # Verify response structure
      expect(generate_response['success']).to be true

      wait_for_rate_limit
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
