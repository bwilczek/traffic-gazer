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

def driving_time(directions:, from:, to:)
  result = directions.query(
    origin: from,
    destination: to,
    mode: 'driving',
    departure_time: Time.now
  )
  result[0]['legs'][0]['duration']['value']
end

#############################
###       THE LOGIC       ###
#############################

config['routes'].each do |route|
  name = route['name'].gsub(' ', '_')
  from = route['from'].gsub(';', '_')
  to = route['to'].gsub(';', '_')
  local_file_name = "tmp/#{name}.csv"
  remote_file_name = "/#{name}.csv"

  duration = driving_time(directions: directions, from: from, to: to)

  FileUtils.rm_f(local_file_name)

  # Pull name.csv from dbx if it exists
  dbx.download(remote_file_name) { |c| File.open(local_file_name, 'w') { |f| f.write(c) } } rescue nil

  # Append the new line
  File.open(local_file_name, 'a') do |f| 
    f.puts("#{from};#{to};#{Time.now.iso8601};#{duration}")
  end 

  # Push created/modified name.csv to dbx
  dbx.upload remote_file_name, File.read(local_file_name), :mode => :overwrite
end
