require 'spec_helper'
require 'open3'

RSpec.describe 'Onetime CLI', :cli do
  let(:bin_path) { File.expand_path('../../bin/onetime', __FILE__) }
  let(:lib_path) { File.expand_path('../../lib', __FILE__) }

  def run_cli(*args)
    cmd = ["ruby", "-I#{lib_path}", bin_path] + args
    stdout, stderr, status = Open3.capture3(*cmd)
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

    it 'rejects flags placed after command arguments (gracefully)' do
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
      stdout, _stderr, status = Open3.capture3("echo 'CLI test secret' | ruby -I#{lib_path} #{bin_path} share")
      expect(status.exitstatus).to eq(0)
      secret_url = stdout.strip
      expect(secret_url).to match(/https:\/\/.*\/secret\/[a-z0-9]+/)

      # Extract key
      secret_key = secret_url.split('/').last

      sleep 1 # Rate limiting

      # Retrieve secret
      result = run_cli('secret', secret_key)
      expect(result[:exitcode]).to eq(0)
      expect(result[:stdout]).to include('CLI test secret')
    end

    it 'creates secret with TTL and retrieves it' do
      stdout, _stderr, status = Open3.capture3("echo 'TTL test' | ruby -I#{lib_path} #{bin_path} share -t 3600")
      expect(status.exitstatus).to eq(0)
      secret_key = stdout.strip.split('/').last

      sleep 1

      result = run_cli('secret', secret_key)
      expect(result[:exitcode]).to eq(0)
      expect(result[:stdout]).to include('TTL test')
    end

    it 'creates secret with passphrase and retrieves it' do
      stdout, _stderr, status = Open3.capture3("echo 'Protected' | ruby -I#{lib_path} #{bin_path} share -p testpass123")
      expect(status.exitstatus).to eq(0)
      secret_key = stdout.strip.split('/').last

      sleep 1

      result = run_cli('secret', '-p', 'testpass123', secret_key)
      expect(result[:exitcode]).to eq(0)
      expect(result[:stdout]).to include('Protected')
    end

    it 'fails to retrieve secret with wrong passphrase' do
      stdout, _stderr, status = Open3.capture3("echo 'Protected2' | ruby -I#{lib_path} #{bin_path} share -p correctpass")
      expect(status.exitstatus).to eq(0)
      secret_key = stdout.strip.split('/').last

      sleep 1

      result = run_cli('secret', '-p', 'wrongpass', secret_key)
      expect(result[:exitcode]).to eq(1) # Command fails with wrong passphrase
      expect(result[:stdout].strip).to be_empty # No secret value displayed
    end

    it 'extracts key from full URL' do
      stdout, _stderr, status = Open3.capture3("echo 'URL test' | ruby -I#{lib_path} #{bin_path} share")
      expect(status.exitstatus).to eq(0)
      secret_url = stdout.strip

      sleep 1

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

      sleep 1

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
  end

  describe 'receipt command', :integration do
    it 'retrieves receipt metadata' do
      # First create a secret to get a metadata key
      output = `echo 'Receipt test' | ruby -I#{lib_path} #{bin_path} -j share`
      json = JSON.parse(output)
      metadata_key = json['record']['metadata']['key']

      sleep 1

      result = run_cli('receipt', metadata_key)
      expect(result[:exitcode]).to eq(0)
      # Receipt outputs YAML by default
      expect(result[:stdout]).to include('key:')
    end

    it 'outputs receipt in JSON format with -j flag' do
      output = `echo 'Receipt JSON test' | ruby -I#{lib_path} #{bin_path} -j share`
      json = JSON.parse(output)
      metadata_key = json['record']['metadata']['key']

      sleep 1

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
      expect(result[:stderr]).to include('Unknown secret')
    end

    it 'handles invalid receipt key gracefully' do
      result = run_cli('receipt', 'invalidmeta12345')
      expect(result[:exitcode]).to eq(1)
      expect(result[:stderr]).to include('Unknown secret')
    end
  end

  describe 'command aliases', :integration do
    it 'uses get as alias for secret command' do
      stdout, _stderr, status = Open3.capture3("echo 'Alias test' | ruby -I#{lib_path} #{bin_path} share")
      expect(status.exitstatus).to eq(0)
      secret_key = stdout.strip.split('/').last

      sleep 1

      result = run_cli('get', secret_key)
      expect(result[:exitcode]).to eq(0)
      expect(result[:stdout]).to include('Alias test')
    end
  end

  describe 'output formats', :integration do
    it 'outputs share in JSON format' do
      stdout, _stderr, status = Open3.capture3("echo 'JSON share' | ruby -I#{lib_path} #{bin_path} -j share")
      expect(status.exitstatus).to eq(0)
      json = JSON.parse(stdout)
      expect(json['success']).to be true
      expect(json['record']['secret']['key']).not_to be_nil
    end

    it 'outputs share in YAML format' do
      stdout, _stderr, status = Open3.capture3("echo 'YAML share' | ruby -I#{lib_path} #{bin_path} -y share")
      expect(status.exitstatus).to eq(0)
      expect(stdout).to include('success:')
      expect(stdout).to include('record:')
    end

    it 'outputs secret in JSON format' do
      stdout, _stderr, _status = Open3.capture3("echo 'JSON retrieve' | ruby -I#{lib_path} #{bin_path} share")
      secret_key = stdout.strip.split('/').last

      sleep 1

      result = run_cli('-j', 'secret', secret_key)
      expect(result[:exitcode]).to eq(0)
      json = JSON.parse(result[:stdout])
      expect(json['record']['secret_value']).to include('JSON retrieve')
    end

    it 'outputs secret in YAML format' do
      stdout, _stderr, _status = Open3.capture3("echo 'YAML retrieve' | ruby -I#{lib_path} #{bin_path} share")
      secret_key = stdout.strip.split('/').last

      sleep 1

      result = run_cli('-y', 'secret', secret_key)
      expect(result[:exitcode]).to eq(0)
      expect(result[:stdout]).to include('secret_value:')
      expect(result[:stdout]).to include('YAML retrieve')
    end
  end
end
