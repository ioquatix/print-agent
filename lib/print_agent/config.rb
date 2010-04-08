# This file is a basis for the server's configuration. This is loaded from
# either ../config/site-config.yml or /etc/print_agent/site-config.yml (in
# that order).
#

require 'yaml'
require 'xmlrpc/client'

module PrintAgent
	CONF_DIR = "/etc/print_agent"
	
	CLIENT_PORT = 4883
	CLIENT_SERVERS_CONF = "client-allowed-servers.yaml"

	SERVER_PORT = 4887
	SERVER_HOST = ENV['SERVER_HOST'] || "127.0.0.1"
	SERVER_CONF = "server-config.yaml"

	module Config
		# Client is the machine trying to print
		def self.client_uri(host, port = CLIENT_PORT)
			return "https://#{host}:#{port}"
		end

		# Server is the auth daemon
		def self.server_uri(host = SERVER_HOST, port = SERVER_PORT)
			return "https://#{host}:#{port}"
		end

		# Agent is the web server for authentication
		def self.print_agent_uri(job_id, host = SERVER_HOST, port = 80)
			return "https://#{host}:#{port}/pending/#{job_id}"
		end
	end

	@server_connection_cache = nil
	def self.server_connection(host = SERVER_HOST)
		if @server_connection_cache == nil
			@server_connection_cache = XMLRPC::Client.new_from_uri(Config.server_uri(host))
		end

		return @server_connection_cache
	end

	def self.resolve_host(host)
		# Return the internal address name (data)
		Socket.gethostbyname(host)[0] rescue nil
	end
end