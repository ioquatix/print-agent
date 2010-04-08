
require 'fileutils'
require 'rexec/environment'

module CUPSYS
	
	class Backend
		def initialize(argv = ARGV, env = ENV, path = $0, stdin = $stdin)
			@argv = argv
			@env = env
			@backends_dir = File.dirname(path)
			
			@job_id = @argv[0]
			@username = @argv[1]
			@title = @argv[2]
			@copies = @argv[3]

			@options = {}
			@options_text = @argv[4]

			@options_text.split(" ").each do |option|
				key, value = option.split("=")
				@options[key] = value
			end
			
			if @argv.size == 6
				@input = @argv[5]
			else
				@input = stdin
			end
			
			@printer_name = @env["PRINTER"]
			@device_uri = @env["DEVICE_URI"]
			
			if @device_uri
				@name, @next_uri = @device_uri.split(":", 2)
				@next_name = @next_uri.split(":", 2)[0]
			
				@next_path = File.join(@backends_dir, @next_name)
			end
		end

		attr :name
		attr :next_name
		attr :next_path
		attr :next_uri

		attr :options

		attr :job_id
		attr :username
		attr :title
		attr :copies
		attr :options
		attr :input

		attr :printer_name
		attr :device_uri

		def client_hostname
			@options['job-originating-host-name']
		end

		def task
			if @argv.size == 0
				return :query
			else
				return :print
			end
		end

		def details
			return {
				"PrinterName" => printer_name,
				"ClientHost" => client_hostname,
				"Username" => username,
				"Title" => title,
				"Copies" => copies,
				"Options" => @options_text,
				"JobID" => job_id
			}
		end

		def run_next!
			RExec.env({"DEVICE_URI" => @next_uri}) do
				exec(@next_path, *@argv)
			end
		end
		
		def write_data(path)
			if IO === @input
				File.open(path, "w") do |f|
					while buf = @input.read(1024 * 8)
						f.write(buf)
					end
				end
			else
				FileUtils.cp(@input, path)
			end
		end
	end
end
