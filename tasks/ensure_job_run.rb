#!/opt/puppetlabs/puppet/bin/ruby
require 'uri'
require 'net/http'
require 'openssl'
require 'json'
require 'puppet'

in_params               = JSON.parse(STDIN.read)
puppet_ensure           = in_params['ensure']
environment             = in_params['environment'] || ''
scope                   = in_params['scope']
name                    = in_params['name']
description             = in_params['description']
noop                    = in_params['noop']
no_noop                 = in_params['no_noop']
concurrency             = in_params['concurrency']
enforce_environment     = in_params['enforce_environment'] || false
debug                   = in_params['debug']
trace                   = in_params['trace']
evaltrace               = in_params['evaltrace']
filetimeout             = in_params['filetimeout']
http_connect_timeout    = in_params['http_connect_timeout']
http_keepalive_timeout  = in_params['http_keepalive_timeout']
ordering                = in_params['ordering']
skip_tags               = in_params['skip_tags']
tags                    = in_params['tags']
use_cached_catalog      = in_params['use_cached_catalog']
usecacheonfailure       = in_params['usecacheonfailure']
target                  = in_params['target']
node_group              = in_params['node_group']
jobs_limit              = in_params['jobs_limit'] || 10
connected_only          = in_params['connected_only']
puppet_master           = in_params['puppet_master']
token_file              = "#{ENV['HOME']}/.puppetlabs/token"

if File.file?(token_file)
  token = File.read(token_file).strip
elsif File.file?('/root/.puppetlabs/token')
  token = File.read('/root/.puppetlabs/token').strip
else
  puts 'Ensure you runnining on Puppet Master with access token'
  exit 1
end

if puppet_master.nil?
  puts 'Ensure you runnining on Puppet Master with a valid access token'
  exit 1
end

# TODO: scope node_group
unless node_group.nil?
  ng = {}
  url = URI("https://#{puppet_master}:4433/classifier-api/v1/groups")
  https = Net::HTTP.new(url.host, url.port)
  https.use_ssl = true
  https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Get.new(url)
  request['X-Authentication'] = token
  response = https.request(request)
  JSON.parse(response.read_body).each { |l| ng[l['name']] = l }
end

if connected_only && scope && scope['nodes']
  url = URI("https://#{puppet_master}:8143/orchestrator/v1/inventory")
  https = Net::HTTP.new(url.host, url.port)
  https.use_ssl = true
  https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Post.new(url)
  request['X-Authentication'] = token
  request['Content-Type'] = 'application/json'
  request.body = scope.to_json
  response = https.request(request)
  if response.is_a?(Net::HTTPSuccess)
    not_connected = JSON.parse(response.read_body)['items'].select { |k| k['connected'] == false }.map { |k| k['name'] }
    scope['nodes'] = scope['nodes'] - not_connected unless not_connected.empty?
    puts "nodes_not_connected: #{not_connected}"
  end
end

url = URI("https://#{puppet_master}:8143/orchestrator/v1/jobs?limit=#{jobs_limit}&type=deploy")
https = Net::HTTP.new(url.host, url.port)
https.use_ssl = true
https.verify_mode = OpenSSL::SSL::VERIFY_NONE
request = Net::HTTP::Get.new(url)
request['X-Authentication'] = token

jobs = {}
response = https.request(request)
JSON.parse(response.read_body)['items'].each do |l|
  jobs[l['name']] = {
    'description' => l['description'],
    'state'       => l['state'],
    'noop'        => l['noop'],
    'environment' => l['environment'],
    'options'     => l['options'],
    'timestamp'   => l['timestamp'],
    'owner'       => l['owner'],
    'node_count'  => l['node_count'],
    'node_states' => l['node_states'],
  }
end

if puppet_ensure == 'present'
  if scope.nil?
    puts "Invalid mandotory fields #{in_params}"
    exit 1
  end

  job_query = {}
  job_query['environment']            = environment unless environment.nil?
  job_query['scope']                  = scope unless scope.nil?
  job_query['description']            = description unless description.nil?
  job_query['noop']                   = noop unless noop.nil?
  job_query['no_noop']                = no_noop unless no_noop.nil?
  job_query['concurrency']            = concurrency unless concurrency.nil?
  job_query['enforce_environment']    = enforce_environment unless enforce_environment.nil?
  job_query['debug']                  = debug unless debug.nil?
  job_query['trace']                  = trace unless trace.nil?
  job_query['evaltrace']              = evaltrace unless evaltrace.nil?
  job_query['filetimeout']            = filetimeout unless filetimeout.nil?
  job_query['http_connect_timeout']   = http_connect_timeout unless http_connect_timeout.nil?
  job_query['http_keepalive_timeout'] = http_keepalive_timeout unless http_keepalive_timeout.nil?
  job_query['ordering']               = ordering unless ordering.nil?
  job_query['skip_tags']              = skip_tags unless skip_tags.nil?
  job_query['tags']                   = tags unless tags.nil?
  job_query['use_cached_catalog']     = use_cached_catalog unless use_cached_catalog.nil?
  job_query['usecacheonfailure']      = usecacheonfailure unless usecacheonfailure.nil?
  job_query['target']                 = target unless target.nil?

  url = URI("https://#{puppet_master}:8143/orchestrator/v1/command/deploy")
  https = Net::HTTP.new(url.host, url.port)
  https.use_ssl = true
  https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Post.new(url)
  request['X-Authentication'] = token
  request['Content-Type'] = 'application/json'
  puts job_query.to_json
  request.body = job_query.to_json
  response = https.request(request)
  if response.is_a?(Net::HTTPSuccess)
    puts JSON.parse(response.read_body)['job']['id']
  else
    puts "#{response.code}-#{response.message}"
    puts response.read_body unless response.read_body.nil?
    exit 1
  end
elsif puppet_ensure == 'absent'
  if description
    jobs1 = jobs.select { |_k, v| v['description'] == description }
    jobs1.each_key do |l1|
      job_query = {}
      job_query['job'] = l1
      url = URI("https://#{puppet_master}:8143/orchestrator/v1/command/stop")
      https = Net::HTTP.new(url.host, url.port)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_NONE
      request = Net::HTTP::Delete.new(url)
      request['X-Authentication'] = token
      request['Content-Type'] = 'application/json'
      puts job_query.to_json
      request.body = job_query.to_json
      response = https.request(request)
      puts response
    end
  end
elsif name
  puts jobs[name]
else
  puts jobs
end
