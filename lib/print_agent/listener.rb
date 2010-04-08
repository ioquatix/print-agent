
require 'set'
require 'webrick'
require 'webrick/https'
require 'xmlrpc/server'

module PrintAgent
	class Listener < XMLRPC::WEBrickServlet
		
		attr :valid_addresses, true

		def valid_address?(ip_addr)
			return false if valid_addresses == nil

			names = Socket.getaddrinfo(ip_addr, 0).collect{|ai| ai[2]}.uniq
			names << ip_addr

			names.each do |name|
				return true if valid_addresses.include?(name)
			end

			return false
		end

		def service(request, response)
			if valid_addresses == nil || valid_address?(request.peeraddr[3])
				super(request, response)
			else
				$stderr.puts "Disallowed incoming connection from #{request.peeraddr[3]}"
				raise WEBrick::HTTPStatus::Forbidden unless check_valid_address(request)
			end
		end
	end
end
