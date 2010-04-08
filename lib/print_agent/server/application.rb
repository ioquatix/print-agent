
require 'logger'
require 'webrick'
require 'webrick/https'
require 'xmlrpc/server'

require 'print_agent/spool'
require 'print_agent/print_job'

require 'print_agent/server'
require 'print_agent/server/statistics'

module PrintAgent
	module Server

		class Application
			def initialize(listener)
				@lock = Mutex.new
				@jobs_queue = {}

				# Setup the spooler
				PrintAgent::spooler.setup

				listener.add_handler("release") { |job_id, status, details| 
					job, status = status_update(job_id.to_i, status.to_sym, details)

					response = {STATUS => status}
					response[PRINTER] = job.printer if job

					# return
					response
				}

				listener.add_handler("spool") { |job_id, client_host, details|
					spool_and_notify(job_id.to_i, client_host, details) != nil
				}

				listener.add_handler("server_status") { 
					server_status
				}

				listener.add_handler("released") { |job_id|
					released? job_id
				}

				@timeout_after = (5 * 60)
				@timeout_running = false
				@timeout_thread = nil

				@stats = Statistics.new

				@logger = Logger.new(STDOUT)
				@logger.level = Logger::DEBUG

				# Get logging to output frequently
				Thread.new {
					STDOUT.flush while sleep 5
				}

				start_timeout_thread
			end

			def shutdown
				@lock.synchronize {
					@jobs_queue.each do |job_id, job|
						@logger.warn "#{job_id}: Server shutdown with job status pending!"
					end
				}

				stop_timeout_thread
			end

			def server_status
				results = nil

				@lock.synchronize {
					results = @jobs_queue.values.collect { |j| j.summary }
				}

				status_values = {"count" => @jobs_queue.size, "queue" => results}
				status_values["time"] = Time.new.to_s
				status_values["stats"] = @stats.values
				status_values["timeout"] = @timeout_after

				return status_values
			end

			def time_out_jobs
				timeout = Time.now - @timeout_after
				@lock.synchronize {
					@jobs_queue.each do |job_id, job|
						if job.older_than timeout
							if (job.pending?)
								@stats.inc :pending_expire
								@logger.warn "#{job_id}: Rejected job after inactivity for at least #{@timeout_after} seconds."
							end

							@jobs_queue.delete(job_id)
						end
					end
				}
			end

			def spool(job_id, details = {}, &block)
				job = nil

				begin
					@lock.synchronize {
						job = @jobs_queue[job_id]
						if job
							@logger.warn "#{job_id}: Trying to spool duplicate job!"
						else
							job = PrintJob.new job_id, details

							@logger.info "#{job_id}: Adding job to queue."
							@jobs_queue[job_id] = job
						end

						@stats.inc :spool

						yield job
					}
				rescue
					@stats.inc :spool_fail

					@logger.fatal "#{job_id}: Exception while spooling job #{$!}"
					return nil
				end

				return job
			end

			def released? (job_id)
				status = nil

				begin
					@lock.synchronize {
						status = (job = @jobs_queue[job_id]) ? job.processing_status : nil
					}
				rescue
					@stats.inc :released_fail

					@logger.fatal "#{job_id}: Exception while checking status #{$!}"
				end

				return status
			end

			def accept(job_id)
				status_update(job_id, :accept)
			end

			def reject(job_id)
				status_update(job_id, :reject)
			end

			def self.setup
				rpc_server = WEBrick::HTTPServer.new(
					:Port => PrintAgent::SERVER_PORT,
					:BindAddress => "0.0.0.0",
					:SSLEnable => true,
					:SSLVerifyClient => OpenSSL::SSL::VERIFY_NONE,
					:SSLCertName => [["CN", WEBrick::Utils::getservername]]
				)

				listener = XMLRPC::WEBrickServlet.new
				auth_server = self.new(listener)
				rpc_server.mount("/RPC2", listener)

				return rpc_server, auth_server
			end

			private
			def status_update(job_id, action, details = {})
				return unless [:accept, :reject].include? action

				@logger.info "#{job_id}: Updating job status to #{action}..."

				result = UNKNOWN
				job = nil

				@lock.synchronize {
					job = @jobs_queue[job_id]

					if job and job.pending?
						details_str = details.keys.collect{ |k| "#{k}=#{details[k]}" }.join(" ")
						@logger.info "#{job_id}: Processing status #{action} with details #{details_str}"
						job.update_details(details)
						job.send(action)

						# Update statistics
						@stats.inc action

						result = OKAY
					elsif job and !job.pending?
						result = DUPLICATE
						@logger.warn "#{job_id}: Job update to #{action} is not first update!"
					else
						@stats.inc :status_update_fail
						@logger.warn "#{job_id}: Status update of non-existant job to #{action}!"
						result = MISSING
					end
				}

				return job, result
			end

			def start_timeout_thread
				return if @timeout_thread != nil
				@timeout_running = true

				@logger.debug "Starting timeout thread"
				@timeout_thread = Thread.new do
					while @timeout_running do
						@logger.debug "Running timeout check on all jobs..."
						time_out_jobs
						@logger.debug "Check complete."
						sleep 30
					end
				end

			end

			def stop_timeout_thread
				if @timeout_thread
					@timeout_running = false
					@logger.debug "Joining with timeout thread..."
					@timeout_thread.exit
					@logger.debug "Join complete."
					@timeout_thread = nil
				end
			end

			def spool_and_notify(job_id, host, details = {})
				status = spool(job_id, details) do |job|
					# This will return immediately
					Thread.new do
						@logger.info "#{job_id}: Notifying client #{host} of pending job. (#{PrintAgent::Config::client_uri(host)})"
						begin
							@stats.inc :notify

							client = XMLRPC::Client.new_from_uri(PrintAgent::Config::client_uri(host))
							result = client.call("pending", PrintAgent::Config::print_agent_uri(job_id), job_id)
						rescue
							@stats.inc :notify_fail

							@logger.warn "#{job_id}: Exception while notifying client of pending job #{$!}"
						end
					end # Thread
				end # Spool block
			end
		end
	end
end
