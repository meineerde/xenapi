module XenApi
  autoload :Client,           File.expand_path('../xenapi/client',            __FILE__)
  autoload :Errors,           File.expand_path('../xenapi/errors',            __FILE__)
  autoload :Dispatcher,       File.expand_path('../xenapi/dispatcher',        __FILE__)
  autoload :AsyncDispatcher,  File.expand_path('../xenapi/async_dispatcher',  __FILE__)

  # Perform some action in a session context
  #
  # @param [String,Array] hosts Host or hosts to try to connect to
  # @param [String] username Username used for login
  # @param [String] password Password used for login
  # @param [Hash(Symbol => Boolean, String)] options
  #   Additional boolean options:
  #     +:api_version+:: Force the usage of this API version
  #     +:slave_login+:: Authenticate locally against a slave in emergency mode if true.
  #     +:keep_session+:: Don't logout afterwards to keep the session usable if true
  # @yield client
  # @yieldparam [Client] client Client instance
  # @return [Object] block return value
  # @raise [NoHostsAvailable] No hosts could be contacted
  def self.do(hosts, username, password, options={})
    hosts = [hosts] unless hosts.respond_to? :shift
    method = options[:slave_login] ? :slave_local_login_with_password : :login_with_password

    until hosts.empty?
      client = Client.new(hosts.shift)
      begin
        begin
          args = [method, username, password]
          args << options[:api_version] if options.has_key?(:api_version)
          client.send(*args)
        rescue Timeout::Error
          next
        rescue Errors::HostIsSlave => e
          uri = URI.parse(host)
          uri.hostname = e.description[0]
          client = Client.new(uri.to_s)
          retry
        end
        return yield client
      ensure
        client.logout unless options[:keep_session] || client.xenapi_session.nil?
      end
    end
    raise Errors::NoHostsAvailable.new("No server reachable. Giving up.")
  end
end

