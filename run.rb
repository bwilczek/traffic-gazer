require 'yaml'
require 'fileutils'
require 'googlemaps/services/client'
require 'googlemaps/services/directions'
require 'dropbox_api'

#########################
###       SETUP       ###
#########################

google_maps_key = ENV['TRAFFIC_GAZER_GOOGLE_MAPS_KEY']
dropbox_key = ENV['TRAFFIC_GAZER_DROPBOX_APP_TOKEN']

config = YAML.load_file('./config.yml')

client = GoogleMaps::Services::GoogleClient.new(key: google_maps_key, response_format: :json)
directions = GoogleMaps::Services::Directions.new(client)
dbx = DropboxApi::Client.new(dropbox_key)

Result = Struct.new(:duration_value, :duration_text, :distance_value, :distance_text)

def driving_time(directions:, from:, to:)
  result = directions.query(
    origin: from,
    destination: to,
    mode: 'driving',
    departure_time: Time.now
  )

  Result.new(
    result[0]['legs'][0]['duration']['value'],
    result[0]['legs'][0]['duration']['text'],
    result[0]['legs'][0]['distance']['value'],
    result[0]['legs'][0]['distance']['text']
  )
end

#############################
###       THE LOGIC       ###
#############################

route_count = config['routes'].count
route_index = 0

config['routes'].each do |route|
  route_index += 1
  name = route['name'].gsub(' ', '_')
  from = route['from'].gsub(';', '_')
  to = route['to'].gsub(';', '_')
  local_file_name = "tmp/#{name}.csv"
  remote_file_name = "/#{name}.csv"

  puts "Processing route: #{name} (#{route_index}/#{route_count})"

  result = driving_time(directions: directions, from: from, to: to)

  puts " > remove old local copy"
  FileUtils.rm_f(local_file_name)

  puts " > pull from dropbox"
  dbx.download(remote_file_name) { |c| File.open(local_file_name, 'w') { |f| f.write(c) } } rescue nil

  # write header row for new files
  unless File.exists?(local_file_name)
    File.open(local_file_name, 'w') do |f|
      f.puts("from;to;time;#{Result.members.join(";")}")
    end
  end

  puts " > append the new line"
  File.open(local_file_name, 'a') do |f|
    f.puts("#{from};#{to};#{Time.now.iso8601};#{result.members.map { |m| result.send(m) }.join(';')}")
  end

  puts " > push to dropbox"
  dbx.upload remote_file_name, File.read(local_file_name), :mode => :overwrite

  # try not to flood the APIs too much
  sleep 2
end
