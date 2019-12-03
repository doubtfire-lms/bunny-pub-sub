# frozen_string_literal: true

require 'zip'
require 'securerandom'

def ack_result(results_publisher, value, task_id, timestamp, output_path)
  return if results_publisher.nil?

  msg = { task_id: task_id, timestamp: timestamp }

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
  "#{Dir.pwd}/app"
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

def run_assessment_script_via_docker(host_path, output_path, random_string, command, tag = 'overseer/dotnet:2.2')
  client_error!({ error: "A valid Docker image name:tag is needed" }, 400) if tag.nil? || tag.to_s.strip.empty?

  puts 'Running docker executable..'

  # TODO: Security:
  # Pass random filename... both `blah.txt` and `blah.yaml`
  # Permit write access ONLY to these files
  # Other security like no network access, capped execution time + resources, etc

  # test:
  # -m 100MB done
  # --stop-timeout 10 (seconds) (isn't for what I thought it was :))
  # --network none (fails reading from https://api.nuget.org/v3/index.json)
  # --read-only (FAILURE without correct exit code)
  # https://docs.docker.com/engine/reference/run/#security-configuration
  # https://docs.docker.com/engine/reference/run/#runtime-constraints-on-resources
  # -u="overseer" (specify default non-root user)

  # TODO: Change OUT_YAML to OUTPUT to decrease transparency.
  result = {
    run_result_message:
    `docker run \
    -m 100MB \
    --restart no \
    --mount type=bind,source=#{host_path},target=/app \
    --rm #{tag} \
    /bin/bash -c "#{command}"`
  }
  # -e"OUT_YAML=#{random_string}.yaml" \

  puts "Docker container exit status code: #{$?.exitstatus}"

  extract_result_files host_path, output_path, random_string, $?.exitstatus

  if $?.exitstatus != 0
    raise Subscriber::ServerException.new result, 500
  end

  result
end

# Step 4
def extract_result_files(s_path, output_path, random_string, exitstatus)
  client_error!({ error: "A valid output_path is needed" }, 400) if output_path.nil? || output_path.to_s.strip.empty?

  puts 'Extracting result file from the pit..'
  FileUtils.mkdir_p output_path

  input_txt_file_name = "#{s_path}/#{random_string}.txt"
  output_txt_file_name = "#{output_path}/output.txt"
  input_yaml_file_name = "#{s_path}/#{random_string}.yaml"
  output_yaml_file_name = "#{output_path}/output.yaml"

  if File.exist? input_txt_file_name
    File.open(input_txt_file_name, 'a') { |f|
      f.puts "exit code: #{exitstatus}"
    }

    if File.exist? output_txt_file_name
      to_append = File.read input_txt_file_name
      File.open(output_txt_file_name, 'a') { |f|
        f.puts ''
        f.puts to_append
      }
    else
      FileUtils.copy(input_txt_file_name, output_txt_file_name)
    end

    # FileUtils.rm input_txt_file_name
  else
    puts "Results file: #{s_path}/#{random_string}.txt does not exist"
  end

  # TODO: Combine yaml file keys `message` and `new_status`.
  # Update status from `blah.yaml`... if it exists etc.
  if File.exist? input_yaml_file_name
    File.open(input_yaml_file_name, 'a') { |f|
      f.puts "exit_code: #{exitstatus}"
    }
    FileUtils.copy(input_yaml_file_name, output_yaml_file_name)
    FileUtils.rm input_yaml_file_name
  else
    puts "Results file: #{s_path}/#{random_string}.yaml does not exist"
  end

end

# Step 5
def cleanup_after_your_own_mess(path)
  return if path.nil?
  return unless File.exist? path

  puts "Recursively force removing: #{path}/*"
  FileUtils.rm_rf(Dir.glob("#{path}/*"))
end

def clean_before_start(path)
  cleanup_after_your_own_mess(path)
end

def valid_zip_file_param?(params)
  !params['zip_file'].nil? && params['zip_file'].is_a?(Integer) && params['zip_file'] == 1
end

def receive(subscriber_instance, channel, results_publisher, delivery_info, _properties, params)
  params = JSON.parse(params)
  return subscriber_instance.client_error!({error: 'PARAM `output_path` is required'}, 400) if params['output_path'].nil?
  return subscriber_instance.client_error!({error: 'PARAM `submission` is required'}, 400) if params['submission'].nil?
  return subscriber_instance.client_error!({error: 'PARAM `assessment` is required'}, 400) if params['assessment'].nil?
  return subscriber_instance.client_error!({error: 'PARAM `timestamp` is required'}, 400) if params['timestamp'].nil?
  return subscriber_instance.client_error!({error: 'PARAM `task_id` is required'}, 400) if params['task_id'].nil?

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

  docker_pit_path = get_docker_task_execution_path # get_task_path(task_id)
  puts "Docker execution path: #{docker_pit_path}"
  unless File.exist? docker_pit_path
    # TODO: Add correct permissions here
    FileUtils.mkdir_p docker_pit_path
  else
    clean_before_start docker_pit_path
  end

  skip_rm = params['skip_rm'] || 0

  if valid_zip_file_param? params
    extract_submission submission, docker_pit_path
  else
    copy_student_files submission, docker_pit_path
  end

  extract_assessment assessment, docker_pit_path

  random_string = "build-#{SecureRandom.hex}"
  # TODO: Pass a param for a Docker image's tag
  result = run_assessment_script_via_docker docker_pit_path, output_path, random_string, "chmod +x /app/build.sh && /app/build.sh #{random_string}.yaml >> /app/#{random_string}.txt"
  random_string = "run-#{SecureRandom.hex}"
  # TODO: Pass a param for a Docker image's tag
  result = run_assessment_script_via_docker docker_pit_path, output_path, random_string, "chmod +x /app/run.sh && /app/run.sh #{random_string}.yaml >> /app/#{random_string}.txt"

rescue Subscriber::ClientException => e
  cleanup_after_your_own_mess docker_pit_path if skip_rm != 1
  channel.ack(delivery_info.delivery_tag)
  puts e.message
  subscriber_instance.client_error!({ error: e.message, task_id: task_id, timestamp: timestamp }, e.status)
rescue Subscriber::ServerException => e
  cleanup_after_your_own_mess docker_pit_path if skip_rm != 1
  channel.ack(delivery_info.delivery_tag)
  puts e.message
  subscriber_instance.server_error!({ error: 'Internal server error', task_id: task_id, timestamp: timestamp }, 500)
rescue StandardError => e
  cleanup_after_your_own_mess docker_pit_path if skip_rm != 1
  channel.ack(delivery_info.delivery_tag)
  puts e.message
  subscriber_instance.server_error!({ error: 'Internal server error', task_id: task_id, timestamp: timestamp }, 500)
else
  cleanup_after_your_own_mess docker_pit_path if skip_rm != 1
  channel.ack(delivery_info.delivery_tag)
  ack_result results_publisher, result, task_id, timestamp, output_path
end
