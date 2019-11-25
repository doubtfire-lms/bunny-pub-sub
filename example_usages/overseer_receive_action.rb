# frozen_string_literal: true

require 'zip'

def ack_result(results_publisher, value, task_id)
  return if results_publisher.nil?

  msg = { message: value, task_id: task_id }

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
  '/Users/akashagarwal/ruby/overseer-pub-sub/lazarus_pit'
end

##################################################################
##################################################################

# Step 1 -- done
def copy_student_files(s_path, path)
  puts "Copying submission files"
  `cp -R #{s_path}/. path`
end

def extract_submission(zip_file, path)
  puts "Extracting submission from zip file"
  extract_zip zip_file, path
end

# Step 2 -- done
def extract_assessment(zip_file, path)
  extract_zip zip_file, path
end

# Step 3
def run_assessment_script(path)
  rpath = "#{path}/run.sh"
  unless File.exist? rpath
    client_error!({ error: "File #{rpath} doesn't exist" }, 500)
  end
  result = {}

  `chmod +x #{rpath}`

  Dir.chdir path do
    result = { run_result_message: `./run.sh` }
  end
  result
end

def run_assessment_script_via_docker(path, image = 'overseer/dotnet:2.2')
  puts "Running docker executable.."
  result = { run_result_message: `docker run -v#{path}:/lazarus_pit --rm #{image}` }
  result
end

# Step 4
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
  return 'PARAM `submission` is required' if params['submission'].nil?
  return 'PARAM `assessment` is required' if params['assessment'].nil?
  return 'PARAM `task_id` is required' if params['task_id'].nil?

  if ENV['RUBY_ENV'].nil? && ENV['RUBY_ENV'] == 'development'
    root_path = ENV['ROOT_PATH']
    params['submission'] = "#{root_path}#{params['submission']}"
    params['assessment'] = "#{root_path}#{params['assessment']}"
  end

  puts params

  unless params['task_id'].is_a?(Integer)
    subscriber_instance.client_error!({ error: "Invalid task_id: #{params['task_id']}" }, 400)
  end

  unless File.exist? params['submission']
    # By default, Overseer will expect a folder path
    if valid_zip_file_param? params
      subscriber_instance.client_error!({ error: "Zip file not found: #{params['submission']}" }, 400)
    else
      subscriber_instance.client_error!({ error: "Folder not found: #{params['submission']}" }, 400)
    end
  end

  unless File.exist? params['assessment']
    subscriber_instance.client_error!({ error: "Zip file not found: #{params['assessment']}" }, 400)
  end

  unless valid_zip? params['submission']
    subscriber_instance.client_error!({ error: "Invalid zip file: #{params['submission']}" }, 400)
  end

  unless valid_zip? params['assessment']
    subscriber_instance.client_error!({ error: "Invalid zip file: #{params['assessment']}" }, 400)
  end

  output_loc = get_docker_task_execution_path || get_task_path(params['task_id'])
  puts "Output loc: #{output_loc}"
  FileUtils.mkdir_p output_loc

  skip_rm = params['skip_rm'] || 0

  if valid_zip_file_param? params
    extract_submission params['submission'], output_loc
  else
    copy_student_files params['submission'], output_loc
  end

  extract_assessment params['assessment'], output_loc

  # TODO: Pass a param for image name here
  result = run_assessment_script_via_docker output_loc
  puts result

rescue Subscriber::ClientException => e
  cleanup_after_your_own_mess output_loc if skip_rm != 1
  channel.ack(delivery_info.delivery_tag)
  subscriber_instance.client_error!({ error: e.message }, e.status)
rescue Subscriber::ServerException => e
  cleanup_after_your_own_mess output_loc if skip_rm != 1
  channel.ack(delivery_info.delivery_tag)
  puts e.message
  subscriber_instance.server_error!({ error: 'Internal server error', task_id: params['task_id'] }, 500)
rescue StandardError => e
  cleanup_after_your_own_mess output_loc if skip_rm != 1
  channel.ack(delivery_info.delivery_tag)
  puts e.message
  subscriber_instance.server_error!({ error: 'Internal server error', task_id: params['task_id'] }, 500)
else
  cleanup_after_your_own_mess output_loc if skip_rm != 1
  channel.ack(delivery_info.delivery_tag)
  ack_result results_publisher, result, params['task_id'] # unless results_publisher.nil?
end
