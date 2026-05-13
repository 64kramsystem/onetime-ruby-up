require 'json'
require 'yaml'

require_relative '../api'
require_relative '../version'

module Onetime
  module CLI
    class Runner
      class Error < StandardError; end

      PROGRAM_NAME = 'onetime'.freeze

      def initialize(parsed, stdin: $stdin, stdout: $stdout, stderr: $stderr)
        @parsed = parsed
        @stdin = stdin
        @stdout = stdout
        @stderr = stderr
      end

      def run
        return print_version if @parsed.show_version

        configure_api!
        case @parsed.command
        when 'status'   then run_status
        when 'receipt'  then run_receipt
        when 'secret'   then run_secret
        when 'share'    then run_share
        when 'generate' then run_generate
        else
          raise Error, "unhandled command: #{@parsed.command.inspect}"
        end
      end

      private

      def print_version
        @stdout.puts Onetime::VERSION
        0
      end

      def configure_api!
        OT::API.base_uri @parsed.base_uri if @parsed.base_uri
        OT::API.debug_output STDERR if @parsed.debug
        @api = OT::API.new(@parsed.custid, @parsed.apikey)
      end

      def run_status
        res = api_get('/status')
        case @parsed.format
        when 'json'
          @stdout.puts res.to_json
        when 'yaml'
          @stdout.puts res.to_yaml
        else
          account = @api.anonymous ? 'Anonymous' : @api.custid
          @stderr.puts '# Host: %s' % OT::API.base_uri
          @stderr.puts '# Account: %s' % account
          @stdout.puts 'Service Status: %s' % res[:status]
        end
        0
      end

      def run_receipt
        raise Error, 'csv not supported' if @parsed.format == 'csv'
        raise Error, "Usage: #{PROGRAM_NAME} receipt <KEY>" if @parsed.argv.empty?

        key = @parsed.argv.first.to_s
        res = api_get('/receipt/%s' % key)
        case @parsed.format
        when 'json'
          @stdout.puts res.to_json
        else
          @stdout.puts res.to_yaml
        end
        0
      end

      def run_secret
        raise Error, 'csv not supported' if @parsed.format == 'csv'
        raise Error, "Usage: #{PROGRAM_NAME} secret <KEY>" if @parsed.argv.empty?

        raw_key = @parsed.argv.first.to_s
        key = OT::API.extract_secret_key(raw_key)
        opts = { continue: true }
        opts[:passphrase] = @parsed.passphrase if @parsed.passphrase
        res = api_post('/secret/%s/reveal' % key, opts)
        case @parsed.format
        when 'json'
          @stdout.puts res.to_json
        when 'yaml'
          @stdout.puts res.to_yaml
        else
          value = res.dig('record', 'secret_value')
          @stdout.puts value if value
        end
        0
      end

      def run_share
        secret_value = read_share_input
        raise Error, 'No secret provided' if secret_value.chomp.empty?

        opts = { secret: secret_value, ttl: @parsed.ttl, recipient: @parsed.recipients }
        opts[:passphrase] = @parsed.passphrase if @parsed.passphrase
        res = api_post('/secret/conceal', opts)
        emit_share_result(res)
        0
      end

      def run_generate
        unless @parsed.argv.empty?
          extras = @parsed.argv
          raise Error, "generate takes no arguments (got: %s). Did you mean: onetime share < %s" % [extras.join(' '), extras.first]
        end
        if !@stdin.tty? && !@stdin.eof?
          raise Error, 'generate does not read stdin. Did you mean: onetime share'
        end
        opts = { ttl: @parsed.ttl, recipient: @parsed.recipients }
        opts[:passphrase] = @parsed.passphrase if @parsed.passphrase
        res = api_post('/secret/generate', opts)
        emit_generate_result(res)
        0
      end

      def read_share_input
        if !@parsed.argv.empty?
          read_argv_files(@parsed.argv)
        elsif !@stdin.tty?
          @stdin.read
        else
          @stderr.puts 'Paste message here (hit control-D to continue):'
          content = @stdin.read
          @stderr.puts
          content
        end
      rescue Interrupt
        @stdout.puts 'Exiting...'
        ''
      end

      def read_argv_files(paths)
        paths.map { |path| File.read(path) }.join
      end

      def emit_share_result(res)
        secret_key = OT::API.secret_key_from_response(res)
        raise Error, 'Unexpected response: missing record.secret.key' unless secret_key

        uri = OT::API.web_uri('secret', secret_key)
        case @parsed.format
        when 'json'
          @stdout.puts res.to_json
        when 'yaml'
          @stdout.puts res.to_yaml
        else
          recipients = OT::API.recipients_from_response(res)
          if !recipients.empty?
            @stderr.puts '# Secret link sent to: %s' % recipients.join(',')
          else
            @stdout.puts uri
          end
        end
      end

      def emit_generate_result(res)
        secret_key = OT::API.secret_key_from_response(res)
        raise Error, 'Unexpected response: missing record.secret.key' unless secret_key

        uri = OT::API.web_uri('secret', secret_key)
        case @parsed.format
        when 'json'
          @stdout.puts res.to_json
        when 'yaml'
          @stdout.puts res.to_yaml
        when 'csv'
          @stdout.puts uri
        else
          recipients = OT::API.recipients_from_response(res)
          if !recipients.empty?
            @stderr.puts '# Secret link sent to: %s' % recipients.join(',')
          else
            @stdout.puts uri
          end
        end
      end

      def api_get(path)
        res = @api.get(path)
        check_response!(res)
        res
      end

      def api_post(path, params)
        res = @api.post(path, params)
        check_response!(res)
        res
      end

      def check_response!(res)
        raise Error, 'Could not complete request' if res.nil?
        return if @api.response.code == 200
        raise Error, OT::API.response_error_message(res)
      end
    end
  end
end
