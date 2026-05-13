require 'spec_helper'
require 'open3'
require 'tempfile'

RSpec.describe 'Onetime CLI', :cli do
  let(:bin_path) { File.expand_path('../../bin/onetime', __FILE__) }
  let(:lib_path) { File.expand_path('../../lib', __FILE__) }

  def run_cli(*args, stdin_data: nil)
    cmd = ["ruby", "-I#{lib_path}", bin_path] + args
    stdout, stderr, status = Open3.capture3(*cmd, stdin_data: stdin_data)
    { stdout: stdout, stderr: stderr, status: status, exitcode: status.exitstatus }
  end

  describe 'version command' do
    it 'shows version with -V flag' do
      result = run_cli('-V')
      expect(result[:exitcode]).to eq(0)
      expect(result[:stdout]).to match(/^\d+\.\d+\.\d+\n?$/)
    end

    it 'shows version with --version flag' do
      result = run_cli('--version')
      expect(result[:exitcode]).to eq(0)
      expect(result[:stdout]).to match(/^\d+\.\d+\.\d+\n?$/)
    end
  end

  describe 'help and usage' do
    it 'handles missing required arguments for secret command' do
      result = run_cli('secret')
      expect(result[:exitcode]).to eq(1)
      expect(result[:stderr]).to match(/Usage.*secret/i)
    end

    it 'handles missing required arguments for receipt command' do
      result = run_cli('receipt')
      expect(result[:exitcode]).to eq(1)
      expect(result[:stderr]).to match(/Usage.*receipt/i)
    end

    it 'errors when share is given a non-existing file path' do
      result = run_cli('share', '/tmp/onetime-no-such-file-xyz123')
      expect(result[:exitcode]).to eq(1)
      combined = result[:stdout] + result[:stderr]
      expect(combined).to match(/no such file/i)
    end
  end

  describe 'global option parsing' do
    it 'accepts -j flag before command name' do
      # This test verifies flag order without making network requests
      # We expect the command to fail because no key is provided, but the parsing should work
      result = run_cli('-j', 'receipt')
      # Should fail due to missing key, not due to bad flag parsing
      expect(result[:stderr]).to match(/Usage.*receipt/i)
      expect(result[:stderr]).not_to match(/Unknown option.*-j/i)
    end

    it 'accepts -y flag before command name' do
      result = run_cli('-y', 'receipt')
      expect(result[:stderr]).to match(/Usage.*receipt/i)
      expect(result[:stderr]).not_to match(/Unknown option.*-y/i)
    end

    it 'rejects flags placed after command arguments (gracefully)', :integration do
      # Before the fix, this would crash with "undefined method `=~' for Array"
      # After the fix, it should handle gracefully (though not ideal UX)
      result = run_cli('secret', 'DUMMYKEY', '-j')
      # Should not crash with undefined method error
      expect(result[:stderr]).not_to match(/undefined method/)
    end
  end

  # Integration-style tests that make real API calls
  describe 'status command', :integration do
    it 'shows status in default format' do
      result = run_cli('status')
      expect(result[:exitcode]).to eq(0)
      expect(result[:stdout]).to include('Service Status:')
      expect(result[:stderr]).to include('Host: https://eu.onetimesecret.com/api')
      expect(result[:stderr]).to include('Account: Anonymous')
    end

    it 'shows status in JSON format with -j flag' do
      result = run_cli('-j', 'status')
      expect(result[:exitcode]).to eq(0)
      json = JSON.parse(result[:stdout])
      expect(json['status']).not_to be_nil
    end

    it 'shows status in YAML format with -y flag' do
      result = run_cli('-y', 'status')
      expect(result[:exitcode]).to eq(0)
      expect(result[:stdout]).to include('status:')
    end
  end

  describe 'share and retrieve workflow', :integration do
    it 'creates and retrieves a secret' do
      # Create secret
      share = run_cli('share', stdin_data: "CLI test secret\n")
      expect(share[:exitcode]).to eq(0)
      secret_url = share[:stdout].strip
      expect(secret_url).to match(/https:\/\/.*\/secret\/[a-z0-9]+/)

      # Extract key
      secret_key = secret_url.split('/').last

      wait_for_rate_limit

      # Retrieve secret
      result = run_cli('secret', secret_key)
      expect(result[:exitcode]).to eq(0)
      expect(result[:stdout]).to include('CLI test secret')
    end

    it 'creates secret with TTL and retrieves it' do
      share = run_cli('share', '-t', '3600', stdin_data: "TTL test\n")
      expect(share[:exitcode]).to eq(0)
      secret_key = share[:stdout].strip.split('/').last

      wait_for_rate_limit

      result = run_cli('secret', secret_key)
      expect(result[:exitcode]).to eq(0)
      expect(result[:stdout]).to include('TTL test')
    end

    it 'creates secret with passphrase and retrieves it' do
      share = run_cli('share', '-p', 'testpass123', stdin_data: "Protected\n")
      expect(share[:exitcode]).to eq(0)
      secret_key = share[:stdout].strip.split('/').last

      wait_for_rate_limit

      result = run_cli('secret', '-p', 'testpass123', secret_key)
      expect(result[:exitcode]).to eq(0)
      expect(result[:stdout]).to include('Protected')
    end

    it 'fails to retrieve secret with wrong passphrase' do
      share = run_cli('share', '-p', 'correctpass', stdin_data: "Protected2\n")
      expect(share[:exitcode]).to eq(0)
      secret_key = share[:stdout].strip.split('/').last

      wait_for_rate_limit

      result = run_cli('secret', '-p', 'wrongpass', secret_key)
      expect(result[:exitcode]).to eq(1) # Command fails with wrong passphrase
      expect(result[:stdout].strip).to be_empty # No secret value displayed
    end

    it 'shares the contents of a file when given as a positional argument' do
      Tempfile.create('share-from-file') do |f|
        f.write("file-content-payload\n")
        f.flush
        share = run_cli('share', f.path)
        expect(share[:exitcode]).to eq(0)
        expect(share[:stdout]).to match(/https:\/\/.*\/secret\/[a-z0-9]+/)
        expect(share[:stderr]).not_to include('Paste message here')
        secret_key = share[:stdout].strip.split('/').last

        wait_for_rate_limit

        retrieve = run_cli('secret', secret_key)
        expect(retrieve[:exitcode]).to eq(0)
        expect(retrieve[:stdout]).to include('file-content-payload')
      end
    end

    it 'extracts key from full URL' do
      share = run_cli('share', stdin_data: "URL test\n")
      expect(share[:exitcode]).to eq(0)
      secret_url = share[:stdout].strip

      wait_for_rate_limit

      result = run_cli('secret', secret_url)
      expect(result[:exitcode]).to eq(0)
      expect(result[:stdout]).to include('URL test')
    end
  end

  describe 'generate command', :integration do
    it 'generates a random secret and returns URL' do
      result = run_cli('generate')
      expect(result[:exitcode]).to eq(0)
      expect(result[:stdout]).to match(/https:\/\/.*\/secret\/[a-z0-9]+/)
    end

    it 'generates secret with TTL' do
      result = run_cli('generate', '-t', '7200')
      expect(result[:exitcode]).to eq(0)
      expect(result[:stdout]).to match(/https:\/\/.*\/secret\/[a-z0-9]+/)
    end

    it 'generates secret with passphrase and retrieves it' do
      result = run_cli('generate', '-p', 'genpass')
      expect(result[:exitcode]).to eq(0)
      secret_key = result[:stdout].strip.split('/').last

      wait_for_rate_limit

      retrieve_result = run_cli('secret', '-p', 'genpass', secret_key)
      expect(retrieve_result[:exitcode]).to eq(0)
      expect(retrieve_result[:stdout]).not_to be_empty
    end

    it 'outputs JSON format with -j flag' do
      result = run_cli('-j', 'generate')
      expect(result[:exitcode]).to eq(0)
      json = JSON.parse(result[:stdout])
      expect(json['success']).to be true
      expect(json['record']).to have_key('secret')
    end

    it 'errors when extra positional arguments are passed' do
      result = run_cli('generate', '/tmp/some-file.csv')
      expect(result[:exitcode]).to eq(1)
      expect(result[:stderr]).to match(/takes no arguments/i)
      expect(result[:stderr]).to match(/onetime share/)
    end

    it 'errors when content is piped via stdin' do
      result = run_cli('generate', stdin_data: "some payload\n")
      expect(result[:exitcode]).to eq(1)
      expect(result[:stderr]).to match(/stdin/i)
      expect(result[:stderr]).to match(/onetime share/)
    end
  end

  describe 'receipt command', :integration do
    it 'retrieves receipt metadata' do
      # First create a secret to get a metadata key
      share = run_cli('-j', 'share', stdin_data: "Receipt test\n")
      json = JSON.parse(share[:stdout])
      metadata_key = json.dig('record', 'receipt', 'key') || json.dig('record', 'metadata', 'key')

      wait_for_rate_limit

      result = run_cli('receipt', metadata_key)
      expect(result[:exitcode]).to eq(0)
      # Receipt outputs YAML by default
      expect(result[:stdout]).to include('key:')
    end

    it 'outputs receipt in JSON format with -j flag' do
      share = run_cli('-j', 'share', stdin_data: "Receipt JSON test\n")
      json = JSON.parse(share[:stdout])
      metadata_key = json.dig('record', 'receipt', 'key') || json.dig('record', 'metadata', 'key')

      wait_for_rate_limit

      result = run_cli('-j', 'receipt', metadata_key)
      expect(result[:exitcode]).to eq(0)
      receipt_json = JSON.parse(result[:stdout])
      expect(receipt_json['record']).to have_key('key')
    end
  end

  describe 'error handling', :integration do
    it 'handles invalid secret key gracefully' do
      result = run_cli('secret', 'invalidkey12345')
      expect(result[:exitcode]).to eq(1)
      expect(result[:stderr]).to match(/MissingSecret|Unknown secret/)
    end

    it 'handles invalid receipt key gracefully' do
      result = run_cli('receipt', 'invalidmeta12345')
      expect(result[:exitcode]).to eq(1)
      expect(result[:stderr]).to match(/MissingSecret|Unknown secret|identifier:/)
    end
  end

  describe 'command aliases', :integration do
    it 'uses get as alias for secret command' do
      share = run_cli('share', stdin_data: "Alias test\n")
      expect(share[:exitcode]).to eq(0)
      secret_key = share[:stdout].strip.split('/').last

      wait_for_rate_limit

      result = run_cli('get', secret_key)
      expect(result[:exitcode]).to eq(0)
      expect(result[:stdout]).to include('Alias test')
    end
  end

  describe 'output formats', :integration do
    it 'outputs share in JSON format' do
      share = run_cli('-j', 'share', stdin_data: "JSON share\n")
      expect(share[:exitcode]).to eq(0)
      json = JSON.parse(share[:stdout])
      expect(json['success']).to be true
      expect(json['record']['secret']['key']).not_to be_nil
    end

    it 'outputs share in YAML format' do
      share = run_cli('-y', 'share', stdin_data: "YAML share\n")
      expect(share[:exitcode]).to eq(0)
      expect(share[:stdout]).to include('success:')
      expect(share[:stdout]).to include('record:')
    end

    it 'outputs secret in JSON format' do
      share = run_cli('share', stdin_data: "JSON retrieve\n")
      secret_key = share[:stdout].strip.split('/').last

      wait_for_rate_limit

      result = run_cli('-j', 'secret', secret_key)
      expect(result[:exitcode]).to eq(0)
      json = JSON.parse(result[:stdout])
      expect(json['record']['secret_value']).to include('JSON retrieve')
    end

    it 'outputs secret in YAML format' do
      share = run_cli('share', stdin_data: "YAML retrieve\n")
      secret_key = share[:stdout].strip.split('/').last

      wait_for_rate_limit

      result = run_cli('-y', 'secret', secret_key)
      expect(result[:exitcode]).to eq(0)
      expect(result[:stdout]).to include('secret_value:')
      expect(result[:stdout]).to include('YAML retrieve')
    end
  end
end
