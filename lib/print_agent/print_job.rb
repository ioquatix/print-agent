
require 'print_agent/spool'

module PrintAgent

	class PrintJob
		def initialize(job_id, details)
			@job_id = job_id
			@details = details
			@status = :pending
			@birth = Time.now
		end

		def summary
			return {'id' => @job_id, 'status' => @status.to_s, 'birth' => @birth.to_s, 'printer' => printer}
		end

		attr_reader :job_id

		def older_than(duration)
			@birth < duration  
		end

		def pending?
			@status == :pending
		end

		def print_file
			return PrintAgent::spooler.print_file(@job_id)
		end

		def spooled?
			return PrintAgent::spooler.spooled?(@job_id)
		end

		def accept
			if pending?
				@status = :accept
				return PrintAgent::spooler.send_to_lpr!(@job_id, @details)
			end
		end

		def accepted?
			@status == :accept
		end

		def reject
			if pending?
				@status = :reject
				return PrintAgent::unspool!(@job_id)
			end
		end

		def rejected?
			@status == :reject
		end

		def status
			@status
		end

		def processing_status
			if accepted?
				return ACCEPTED
			elsif rejected?
				return REJECTED
			else
				return PENDING
			end
		end

		def update_details(new_details)
			new_details.each {|k,v| @details[k] = v}
		end

		def details
			@details
		end

		def printer
			@details["PrinterName"]
		end
	end
end