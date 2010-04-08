
require 'print_agent/spool'

module PrintAgent
	module Tasks
		ATTEMPTS = 4

		def self.release(job_id, status, details, server=nil)
			server ||= PrintAgent::server_connection

			result = nil
			attempts = 0

			while result == nil and attempts < ATTEMPTS
				attempts += 1

				begin
					result = server.call("release", job_id, status, details)
				rescue
					$stderr.warn "#{job_id}: Could not connect to remote server: #{$!.faultString}" if @logger
					result = nil
				end

				sleep attempts * 5 if result == nil and attempts < ATTEMPTS
			end

			return result
		end

		def self.spool(job_id, client, details, server=nil)
			server ||= PrintAgent::server_connection

			attempts = 0
			spooled = false

			while spooled == false and attempts < ATTEMPTS
				attempts += 1

				begin
					spooled = server.call("spool", job_id, client, details)
				rescue
					$stderr.warn "#{job_id}: Could not connect to remote server: #{$!.summary}" if @logger
					spooled = false
				end

				sleep attempts * 5 if spooled == false and attempts < ATTEMPTS
			end

			return spooled
		end

		def self.spool_cups_job(backend, server = nil)
			server ||= PrintAgent::server_connection

			PrintAgent::spooler.spool!(backend.job_id) do |print_file|
				$backend.write_data(print_file)
			end

			result = self.spool(backend.job_id, backend.client_hostname, backend.details, server)

			PrintAgent::spooler.unspool!(job_id) if result == false

			return result
		end
	end
end
