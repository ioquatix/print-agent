
require 'rexec/daemon'
require 'print_agent/server/application'

module PrintAgent
	module Server
		class Daemon < RExec::Daemon::Base
			def self.run
				@@server, @@daemon = PrintAgent::Server::Application.setup

				@@server.start
			end

			def self.shutdown
				begin
					@@server.shutdown
				rescue
					puts $!
				end

				begin
					@@daemon.shutdown
				rescue
					puts $!
				end
			end
		end
	end
end
