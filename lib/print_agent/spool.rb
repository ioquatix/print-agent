
require 'fileutils'
require 'yaml'

module PrintAgent
	def self.spooler
		return Spool.new
	end
	
	class Spool
		def initialize(path = "/var/spool/print_agent")
			@path = path
		end
		
		def setup
			FileUtils.mkdir_p @path
			FileUtils.chmod 0777, @path
		end
		
		def print_file(job_id)
			File.join(@path, "job_#{job_id}.prn")
		end
		
		def spooled?(job_id)
			File.exist?(print_file(job_id))
		end
		
		def unspool!(job_id)
			FileUtils.rm_f print_file(job_id)
		end
		
		def spool!(job_id, &block)
			unspool!(job_id) if spooled?(job_id)
			
			path = print_file(job_id)
			
			yield path
			
			FileUtils.chmod 0777, path
		end
		
		def send_to_lpr!(job_id, env)
			if env['Dump']
				env_path = "/tmp/#{job_id}.env"
				File.open(env_path, "w") { |f| f.write(YAML::dump(env)) }
				FileUtils.chmod 0777, env_path
			end
			
			unless spooled?(job_id)
				$stderr.puts "#{job_id}: Cannot spool to lpr, spool files do not exist!"
				return false
			end
			
			args = ["lpr", "-P", env["PrinterName"]]

			# -l: Specifies that the print file is already formatted 
			# for the destination and should be sent without filtering
			# This option is equivalent to "-oraw".
			args << '-l'

			# Delete the file after printing it
			#args << "-r"

			args << "-T" << env["Title"].to_s if env["Title"]
			args << "-U" << env["Username"].to_s if env["Username"]
			args << "-o" << env["Options"] if env["Options"]
			# Job's billing code (lp -o job-billing=SomeCode file.ps)
			args << "-o" << "job-billing=#{env['Billing']}" if env["Billing"] and env["Billing"].size > 0

			# Status: accepted
			args << "-o" << "print-agent-status=accepted"

			args << print_file(job_id)

			$stderr.puts "#{job_id}: #{args.to_cmd}"
			system(*args)

			unspool!(job_id)

			return $?.exitstatus == 0
		end
	end
end
