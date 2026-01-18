

require 'httparty'
require 'uri'

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
    module VERSION
      @path = File.join(Onetime::API::HOME, 'VERSION')
      class << self
        attr_reader :version, :path
        def version
          @version || read_version
        end
        def read_version
          return if @version
          @version = File.read(path).strip!
        end
        def prerelease?() false end
        def to_a()     version.split('.')   end
        def to_s()     version              end
        def inspect()  version              end
      end
    end
  end
  class API
    include HTTParty
    base_uri 'https://eu.onetimesecret.com/api'
    format :json
    headers 'X-Onetime-Client' => 'ruby: %s/%s' % [RUBY_VERSION, Onetime::API::VERSION.to_s]
    attr_reader :opts, :response, :custid, :key, :default_params, :anonymous
    def initialize custid=nil, key=nil, opts={}
      unless ENV['ONETIME_HOST'].to_s.empty?
        self.class.base_uri ENV['ONETIME_HOST']
      end
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
    def post path, params=nil
      opts = self.opts.clone
      body_params = (params || {}).merge default_params

      # V2 API uses JSON format
      opts[:headers] = (opts[:headers] || {}).merge({
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      })

      # Only /secret/conceal and /secret/generate wrap params in "secret" key
      # Other endpoints (reveal, burn, etc.) do NOT wrap
      if path =~ /\/secret\/(conceal|generate)$/
        body_params = { secret: body_params }
      end

      opts[:body] = body_params.to_json

      execute_request :post, path, opts
    end
    def api_path *args
      args.unshift ['', 'v2'] # force leading slash and v2 version
      path = args.flatten.join('/')
      path.gsub(/\/+/, '/')
    end
    private
    def execute_request meth, path, opts
      path = api_path [path]
      @response = self.class.send meth, path, opts
      result = self.class.indifferent_params @response.parsed_response
      result
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
    end
  end
end
OT = Onetime unless defined?(OT)
