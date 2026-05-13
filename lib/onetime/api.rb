

require 'httparty'
require 'uri'
require_relative 'version'

begin
  require 'yajl-ruby'
rescue LoadError => ex
  require 'json'
end

begin
  require 'yaml'
rescue LoadError => ex
end


# Onetime::API - v0.3
#
# A basic client library for the onetimesecret.com API.
#
# Usage:
#
#     api = OT::API.new 'delano@onetimesecret.com', '4eb33c6340006d6607c813fc7e707a32f8bf5342'
#
#     api.get '/status'
#       # => {'status' => 'nominal'}
#
#     api.post '/generate', :passphrase => 'yourspecialpassphrase'
#       # => {'value' => '3Rg8R2sfD3?a', 'metadata_key' => '...', 'secret_key' => '...'}
#
module Onetime
  class API
    unless defined?(Onetime::API::HOME)
      HOME = File.expand_path File.join(File.dirname(__FILE__), '..', '..')
    end
  end
  class API
    include HTTParty
    base_uri 'https://eu.onetimesecret.com/api'
    format :json
    headers 'X-Onetime-Client' => 'ruby: %s/%s' % [RUBY_VERSION, Onetime::VERSION]
    attr_reader :opts, :response, :custid, :key, :default_params, :anonymous, :apiversion
    def initialize custid=nil, key=nil, opts={}
      unless ENV['ONETIME_HOST'].to_s.empty?
        self.class.base_uri ENV['ONETIME_HOST']
      end
      @apiversion = opts.delete(:apiversion) || opts.delete('apiversion') || 2
      @opts = opts
      @default_params = {}
      @custid = custid || ENV['ONETIME_CUSTID']
      @key = key || ENV['ONETIME_APIKEY']
      if @custid.to_s.empty? && @key.to_s.empty?
        @anonymous = true
      elsif @custid.to_s.empty? || @key.to_s.empty?
        raise RuntimeError, "You provided a custid without an apikey" if @key.to_s.empty?
        raise RuntimeError, "You provided an apikey without a custid" if @custid.to_s.empty?
      else
        @anonymous = false
        opts[:basic_auth] ||= { :username => @custid, :password => @key }
      end
    end
    def get path, params=nil
      opts = self.opts.clone
      opts[:query] = (params || {}).merge default_params
      execute_request :get, path, opts
    end
    def post path, params=nil, request_opts={}
      opts = self.opts.clone
      wrap = if request_opts.key?(:wrap)
        request_opts[:wrap]
      elsif request_opts.key?('wrap')
        request_opts['wrap']
      else
        :auto
      end
      body_params = (params || {}).merge default_params

      # V2 API uses JSON format
      opts[:headers] = (opts[:headers] || {}).merge({
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      })

      if wrap_secret_body?(path, wrap)
        body_params = { secret: body_params }
      end

      opts[:body] = body_params.to_json

      execute_request :post, path, opts
    end
    def api_path *args
      args.unshift ['', "v#{apiversion}"] # force leading slash and version
      path = args.flatten.join('/')
      path.gsub(/\/+/, '/')
    end
    private
    def wrap_secret_body?(path, wrap)
      return false if wrap == false || wrap.nil?
      return true if wrap == :secret
      api_path(path).match?(%r{\A/v\d+/secret/(conceal|generate)/?\z})
    end

    def execute_request meth, path, opts
      path = api_path [path]
      @response = self.class.send meth, path, opts
      self.class.indifferent_params @response.parsed_response
    end
    class << self
      def web_uri *args
        uri = URI.parse(OT::API.base_uri)
        uri.path = web_path *args
        uri
      end
      def web_path *args
        args.unshift [''] # force leading slash
        path = args.flatten.join('/')
        path.gsub(/\/+/, '/')
      end
      def indifferent_params(params)
        if params.is_a?(Hash)
          params = indifferent_hash.merge(params)
          params.each do |key, value|
            next unless value.is_a?(Hash) || value.is_a?(Array)
            params[key] = indifferent_params(value)
          end
        elsif params.is_a?(Array)
          params.collect! do |value|
            if value.is_a?(Hash) || value.is_a?(Array)
              indifferent_params(value)
            else
              value
            end
          end
        end
      end
      def indifferent_hash
        Hash.new {|hash,key| hash[key.to_s] if Symbol === key }
      end
      def extract_secret_key(value, api_base_uri=base_uri)
        return value unless value

        uri = URI.parse(value.to_s)
        return value unless uri.host && uri.path
        return value unless accepted_secret_host?(uri.host, api_base_uri)

        match = uri.path.match(%r{\A/secret/([a-zA-Z0-9]+)\z})
        match ? match[1] : value
      rescue URI::InvalidURIError
        value
      end

      def response_error_message(response)
        return 'Could not complete request' if response.nil?

        # Symbol lookups preserve behavior for plain Ruby hashes even though
        # parsed API responses usually support indifferent access.
        ['message', :message, 'error', :error, 'field', :field].each do |key|
          value = response[key] if response.respond_to?(:[])
          return value.to_s unless value.to_s.empty?
        end
        response.to_s
      end

      def secret_key_from_response(response)
        response&.dig('record', 'secret', 'key')
      end

      def receipt_key_from_response(response)
        response&.dig('record', 'receipt', 'key') || response&.dig('record', 'metadata', 'key')
      end

      def recipients_from_response(response)
        recipients = response&.dig('record', 'receipt', 'recipients')
        if recipients.nil? || recipients == '' || (recipients.is_a?(Array) && recipients.empty?)
          recipients = response&.dig('details', 'recipient')
        end
        Array(recipients).flatten.compact.reject { |recipient| recipient.to_s.empty? }
      end

      private

      def accepted_secret_host?(host, api_base_uri)
        configured_host = URI.parse(api_base_uri.to_s).host
        host == configured_host || host == 'onetimesecret.com' || host.end_with?('.onetimesecret.com')
      rescue URI::InvalidURIError
        host == 'onetimesecret.com' || host.end_with?('.onetimesecret.com')
      end
    end
  end
end
OT = Onetime unless defined?(OT)
