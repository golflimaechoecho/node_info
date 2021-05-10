#!/opt/puppetlabs/puppet/bin/ruby
require 'uri'
require 'net/http'
require 'openssl'
require 'json'
require 'puppet'

result = {}
result['exit_code'] = 0

in_params               = JSON.parse(STDIN.read)
puppet_ensure           = in_params['ensure']
id                      = in_params['id']
job_id                  = "/#{id}" unless id.nil?
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
expected_state          = in_params['expected_state']
state_wait_timeout      = in_params['state_wait_timeout'] || 300
state_wait_sleep        = in_params['state_wait_sleep'] || 2
puppet_master           = in_params['puppet_master']
token_file              = "#{ENV['HOME']}/.puppetlabs/token"
result['in']            = in_params
# exclude_fields          = [ 'report', 'events', 'nodes,owner', 'userdata', 'status,options' ]
log_level               = in_params['log_level']

def api_get(uri, header = {})
  url = URI(uri)
  https = Net::HTTP.new(url.host, url.port)
  https.use_ssl = true if %r{https}.match?(uri)
  https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Get.new(url)
  header.each do |k, v|
    request[k] = v
  end
  https.request(request)
end

def api_post(uri, content = nil, header = {})
  url = URI(uri)
  https = Net::HTTP.new(url.host, url.port)
  https.use_ssl = true if %r{https}.match?(uri)
  https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Post.new(url)
  request.body = content.to_json if content
  header.each do |k, v|
    request[k] = v
  end
  https.request(request)
end

def api_delete(uri, content = nil, header = {})
  url = URI(uri)
  https = Net::HTTP.new(url.host, url.port)
  https.use_ssl = true if %r{https}.match?(uri)
  https.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Delete.new(url)
  request.body = content.to_json if content
  header.each do |k, v|
    request[k] = v
  end
  https.request(request)
end

def puppet_token(token_file)
  if File.file?(token_file)
    File.read(token_file).strip
  else
    File.file?('/root/.puppetlabs/token')
    File.read('/root/.puppetlabs/token').strip
  end
end

if puppet_master.nil?
  result['exit_code'] = 1
  result[:_error] = { msg:  'Missing puppet master param',
                      kind: 'cheehuan-node_info/missing_puppet_master_param',
                      details: { puppet_master: puppet_master } }
  puts result.to_json
  exit result['exit_code']
end

token = puppet_token(token_file)
if token.nil?
  result['exit_code'] = 1
  result[:_error] = { msg:  'Invalid Puppet access token',
                      kind: 'cheehuan-node_info/invalid_access_token',
                      details: { token_file: token_file } }
  puts result.to_json
  exit result['exit_code']
end

api_header = { 'X-Authentication' => token, 'Content-Type' => 'application/json' }

# scope - node_group (not used yet)
unless node_group.nil?
  ng = {}
  response = api_get("https://#{puppet_master}:4433/classifier-api/v1/groups", api_header)
  JSON.parse(response.read_body).each { |l| ng[l['name']] = l } if response.is_a?(Net::HTTPSuccess)
  if ng[node_group].nil?
    result[:_error] = { msg:  'Invalid node group',
                        kind: 'cheehuan-node_info/invalid_node_group',
                        details: { node_group: node_group } }
    result['exit_code'] = 1
    puts result.to_json
    exit result['exit_code']
  end
end

# Get connected nodes
if connected_only && scope && scope['nodes']
  response = api_post("https://#{puppet_master}:8143/orchestrator/v1/inventory", scope, api_header)
  if response.is_a?(Net::HTTPSuccess)
    nodes_unreachable = JSON.parse(response.read_body)['items'].select { |k| k['connected'] == false }.map { |k| k['name'] }
    unless nodes_unreachable.empty?
      scope['nodes'] = scope['nodes'] - nodes_unreachable
      result['warn'] = [ { 'nodes_unreachable' => nodes_unreachable } ]
    end
  end
  # No exit even no connected nodes found
  if scope['nodes'].empty?
    result[:_error] = { msg:  'No connected nodes found',
                        kind: 'cheehuan-node_info/no_connected_nodes',
                        details: { nodes: scope['nodes'] } }
    result['exit_code'] = 1
    puts result.to_json
  end
end

# Jobs list
jobs = {}
response = api_get("https://#{puppet_master}:8143/orchestrator/v1/jobs#{job_id}?limit=#{jobs_limit}&type=deploy", api_header)
jobs_data = JSON.parse(response.read_body) if response.is_a?(Net::HTTPSuccess)
if jobs_data && jobs_data['items']
  jobs_data['items'].each do |l|
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
else
  jobs = jobs_data
end

if puppet_ensure == 'present'
  if scope.nil?
    result[:_error] = { msg:  'Missing mandatory fields',
                        kind: 'cheehuan-node_info/missing_mandatory' }
    result['exit_code'] = 1
    puts result.to_json
    exit result['exit_code']
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

  result['debug'] = [ { 'api_post' => job_query.to_json } ] if log_level == 'debug'
  response = api_post("https://#{puppet_master}:8143/orchestrator/v1/command/deploy", job_query, api_header)
  if response.is_a?(Net::HTTPSuccess)
    result['out'] = JSON.parse(response.read_body)
    id = result['out']['job']['name']
  else
    result[:_error] = { msg:  'Unable to submit job run.',
                        kind: 'cheehuan-node_info/api_post',
                        details: { message: response.message,
                                   http_code: response.code } }
    result['exit_code'] = 1
    puts result.to_json
    exit result['exit_code']
  end
elsif puppet_ensure == 'absent'
  if description
    jobs1 = jobs.select { |_k, v| v['description'] == description }
    jobs1.each_key do |l1|
      job_query = {}
      job_query['job'] = l1
      response = api_delete("https://#{puppet_master}:8143/orchestrator/v1/command/stop", job_query, api_header)
      result['out'] = response
    end
  end
elsif name
  result['out'] = jobs[name] if jobs[name]
else
  result['out'] = jobs
end

# Wait state
job_state = ''
state_wait_time = state_wait_timeout
until expected_state.nil? || id.nil? || expected_state.include?(job_state) || state_wait_time < 0
  response = api_get("https://#{puppet_master}:8143/orchestrator/v1/jobs/#{id}", api_header)
  if response.is_a?(Net::HTTPSuccess)
    job = JSON.parse(response.read_body)
    job_state = job['state']
    # puts "id: #{id} - #{job_state}, #{state_wait_time}"
  else
    result[:_error] = { msg: 'Job run state wait unexpected',
                        kind: 'cheehuan-node_info/api_get',
                        details: { message: response.message,
                                  http_code: response.code } }
    result['exit_code'] = 1
    puts result.to_json
    exit result['exit_code']
  end
  sleep(state_wait_sleep) if state_wait_sleep > 0 && !expected_state.include?(job_state)
  state_wait_time -= state_wait_sleep
end

puts result.to_json
