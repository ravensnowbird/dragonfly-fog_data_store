require 'fog'
require 'dragonfly'

Dragonfly::App.register_datastore(:fog){ Dragonfly::FogDataStore }

module Dragonfly
  class FogDataStore

    # Exceptions
    class NotConfigured < RuntimeError; end

    def initialize(opts={})
      @bucket_name        = opts[:bucket_name]
      @rackspace_region   = opts[:rackspace_region]
      @rackspace_api_key  = opts[:rackspace_api_key]
      @rackspace_username = opts[:rackspace_username]
      @url_scheme         = opts[:url_scheme] || 'http'
      @url_host           = opts[:url_host]
    end

    attr_accessor :bucket_name, :rackspace_api_key, :rackspace_username, :url_scheme, :url_host, :rackspace_region

    def write(content, opts={})
      ensure_configured
      ensure_bucket_initialized

      headers = {'Content-Type' => content.mime_type}
      headers.merge!(opts[:headers]) if opts[:headers]
      uid = opts[:path] || generate_uid(content.name || 'file')

      rescuing_socket_errors do
        content.file do |f|
          storage.put_object(bucket_name, uid, f, headers)
        end
      end

      uid
    end

    def read(uid)
      ensure_configured
      response = rescuing_socket_errors{ storage.get_object(bucket_name, uid) }
      [response.body, response.headers]
    rescue Excon::Errors::NotFound => e
      nil
    end

    def destroy(uid)
      rescuing_socket_errors{ storage.delete_object(bucket_name, uid) }
    rescue Excon::Errors::NotFound, Excon::Errors::Conflict => e
      Dragonfly.warn("#{self.class.name} destroy error: #{e}")
    end

    def url_for(uid, opts={})
      if opts && opts[:expires]
        storage.get_object_https_url(bucket_name, uid, opts[:expires])
      else
        scheme = opts[:scheme] || url_scheme
        host   = opts[:host]   || url_host
        "#{scheme}://#{host}/#{uid}"
      end
    end

    def storage
      @storage ||= begin
        storage = Fog::Storage.new({
          provider: 'Rackspace',
          rackspace_region: rackspace_region,
          rackspace_api_key: rackspace_api_key,
          rackspace_username: rackspace_username
        }.reject {|name, option| option.nil?})
        storage
      end
    end

    def bucket_exists?
      #rescuing_socket_errors{ storage.get_bucket_location(bucket_name) }
      true
    rescue Excon::Errors::NotFound => e
      false
    end

    private

    def ensure_configured
      unless @configured
        [:bucket_name, :rackspace_api_key, :rackspace_username].each do |attr|
          raise NotConfigured, "You need to configure #{self.class.name} with #{attr}" if send(attr).nil?
        end
        @configured = true
      end
    end

    def ensure_bucket_initialized
      unless @bucket_initialized
        rescuing_socket_errors{ storage.put_bucket(bucket_name, 'LocationConstraint' => rackspace_region) } unless bucket_exists?
        @bucket_initialized = true
      end
    end

    def generate_uid(name)
      "#{Time.now.strftime '%Y/%m/%d/%H/%M/%S'}/#{rand(1000)}/#{name.gsub(/[^\w.]+/, '_')}"
    end

    def rescuing_socket_errors(&block)
      yield
    rescue Excon::Errors::SocketError => e
      storage.reload
      yield
    end

  end
end

