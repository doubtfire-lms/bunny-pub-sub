# frozen_string_literal: true

require 'zip'

def ack_result(results_publisher, value, task_id, timestamp)
  return if results_publisher.nil?

  msg = { message: value, task_id: task_id, timestamp: timestamp }

  results_publisher.connect_publisher
  results_publisher.publish_message msg
  results_publisher.disconnect_publisher
end

def valid_zip?(file)
  begin
    zip = Zip::File.open(file)
    return true
  rescue StandardError => e
    raise e
  ensure
    zip&.close
  end
  false
end

# Flat extract a zip file, no sub-directories.
def extract_zip(input_zip_file_path, output_loc)
  Zip::File.open(input_zip_file_path) do |zip_file|
    # Handle entries one by one
    zip_file.each do |entry|
      # Extract to file/directory/symlink
      puts "Extracting #{entry.name} #{entry.ftype}"
      pn = Pathname.new entry.name
      unless entry.ftype.to_s == 'directory'
        entry.extract "#{output_loc}/#{pn.basename}"
      end
    end
    # # Find specific entry
    # entry = zip_file.glob('*.csv').first
    # puts entry.get_input_stream.read
  end
end

def get_task_path(task_id)
  "student_projects/task_#{task_id}"
end

def get_docker_task_execution_path
  # Docker volumes needs absolute source and destination paths
  "#{Dir.pwd}/lazarus_pit"
end

##################################################################
##################################################################

# Step 1 -- done
def copy_student_files(s_path, d_path)
  puts 'Copying submission files'
  `cp -R #{s_path}/. #{d_path}`
end

def extract_submission(zip_file, d_path)
  puts 'Extracting submission from zip file'
  extract_zip zip_file, d_path
end

# Step 2 -- done
def extract_assessment(zip_file, path)
  extract_zip zip_file, path
end

# Step 3
def run_assessment_script(path)
  rpath = "#{path}/run.sh"
  unless File.exist? rpath
    client_error!({ error: "File #{rpath} doesn't exist" }, 400)
  end
  result = {}

  `chmod +x #{rpath}`

  Dir.chdir path do
    result = { run_result_message: `./run.sh` }
  end
  result
end

def run_assessment_script_via_docker(host_path, tag = 'overseer/dotnet:2.2')
  client_error!({ error: "A valid Docker image name:tag is needed" }, 400) if tag.nil? || tag.to_s.strip.empty?

  puts 'Running docker executable..'
  result = { run_result_message: `docker run -v#{host_path}:/lazarus_pit --rm #{tag}` }
  result
end

# Step 4
def extract_result_files(s_path, output_path)
  client_error!({ error: "A valid output_path is needed" }, 400) if output_path.nil? || output_path.to_s.strip.empty?

  puts 'Extracting result file from the pit..'
  FileUtils.mkdir_p output_path
  FileUtils.copy("#{s_path}/output.txt", output_path)
end

# Step 5
def cleanup_after_your_own_mess(path)
  return if path.nil?
  return unless File.exist? path

  puts 'Recursively force removing: ' + path
  FileUtils.rm_rf path
end

def valid_zip_file_param?(params)
  !params['zip_file'].nil? && params['zip_file'].is_a?(Integer) && params['zip_file'] == 1
end

def receive(subscriber_instance, channel, results_publisher, delivery_info, _properties, params)
  params = JSON.parse(params)
  return 'PARAM `output_path` is required' if params['output_path'].nil?
  return 'PARAM `submission` is required' if params['submission'].nil?
  return 'PARAM `assessment` is required' if params['assessment'].nil?
  return 'PARAM `timestamp` is required' if params['timestamp'].nil?
  return 'PARAM `task_id` is required' if params['task_id'].nil?

  if !ENV['RUBY_ENV'].nil? && ENV['RUBY_ENV'] == 'development'
    puts 'Running in development mode.'\
    ' Prepending ROOT_PATH to submission, assessment and output_path params.'
    root_path = ENV['ROOT_PATH']
    params['output_path'] = "#{root_path}#{params['output_path']}"
    params['submission'] = "#{root_path}#{params['submission']}"
    params['assessment'] = "#{root_path}#{params['assessment']}"
  end

  puts params

  output_path = params['output_path']
  submission = params['submission']
  assessment = params['assessment']
  timestamp = params['timestamp']
  task_id = params['task_id']

  unless task_id.is_a?(Integer)
    subscriber_instance.client_error!({ error: "Invalid task_id: #{task_id}" }, 400)
  end

  unless File.exist? submission
    if valid_zip_file_param? params
      subscriber_instance.client_error!({ error: "Zip file not found: #{submission}" }, 400)
    else
      # By default, Overseer will expect a folder path
      subscriber_instance.client_error!({ error: "Folder not found: #{submission}" }, 400)
    end
  end

  unless File.exist? assessment
    subscriber_instance.client_error!({ error: "Zip file not found: #{assessment}" }, 400)
  end

  unless valid_zip? submission
    subscriber_instance.client_error!({ error: "Invalid zip file: #{submission}" }, 400)
  end

  unless valid_zip? assessment
    subscriber_instance.client_error!({ error: "Invalid zip file: #{assessment}" }, 400)
  end

  output_loc = get_docker_task_execution_path # get_task_path(task_id)
  puts "Output loc: #{output_loc}"
  FileUtils.mkdir_p output_loc

  skip_rm = params['skip_rm'] || 0

  if valid_zip_file_param? params
    extract_submission submission, output_loc
  else
    copy_student_files submission, output_loc
  end

  extract_assessment assessment, output_loc

  # TODO: Pass a param for tag name here
  result = run_assessment_script_via_docker output_loc
  extract_result_files output_loc, output_path

rescue Subscriber::ClientException => e
  cleanup_after_your_own_mess output_loc if skip_rm != 1
  channel.ack(delivery_info.delivery_tag)
  subscriber_instance.client_error!({ error: e.message }, e.status)
rescue Subscriber::ServerException => e
  cleanup_after_your_own_mess output_loc if skip_rm != 1
  channel.ack(delivery_info.delivery_tag)
  puts e.message
  subscriber_instance.server_error!({ error: 'Internal server error', task_id: task_id }, 500)
rescue StandardError => e
  cleanup_after_your_own_mess output_loc if skip_rm != 1
  channel.ack(delivery_info.delivery_tag)
  puts e.message
  subscriber_instance.server_error!({ error: 'Internal server error', task_id: task_id }, 500)
else
  cleanup_after_your_own_mess output_loc if skip_rm != 1
  channel.ack(delivery_info.delivery_tag)
  ack_result results_publisher, result, task_id, timestamp # unless results_publisher.nil?
end
