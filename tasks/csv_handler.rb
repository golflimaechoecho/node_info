#!/opt/puppetlabs/puppet/bin/ruby

# Puppet Task Name: csv_handler
#
require 'csv'
require 'json'
require 'digest/sha1'
require 'puppet'

result = {}
result['exit_code'] = 0

now = Time.new

params          = JSON.parse(STDIN.read)
# Set parameters to local variables and resolve defaults if required
csv_filename    = params['csv_filename']
target_dir      = params['target_dir'] || '/var/puppetlabs/data/node_info/validated'
err_target_dir  = params['err_target_dir'] || '/var/puppetlabs/data/node_info/out'
key_field       = params['key_field'] || 'hostname'
feed_type       = params['feed_type'] || 'common'
basename        = params['basename']
multiple        = params['multiple']
enconding       = params['enconding'] || 'windows-1251' # 'iso-8859-1'
skipped_field   = params['skipped_field'] || []
result['in']    = params

def sanitize_filename(filename)
  fn = filename.split %r{(?<=.)\.(?=[^.])(?!.*\.[^.])}m
  fn.map! { |s| s.gsub %r{[^a-z0-9\-]+}i, '_' }
  fn.join '.'
end

def output(filename, content, multiple)
  if File.file?(filename) && multiple == true
    f = File.read(filename)
    hash_data = JSON.parse(f)
    hash_data = [hash_data] unless hash_data.is_a?(Array)
    hash_data.delete_if { |k| k == content }
    hash_data << content
    f = File.new(filename, 'w')
    f.write(hash_data.to_json)
  else
    f = File.new(filename, 'w')
    f.write(content.to_json)
  end
  f.close
end

def output_err(filename, content)
  File.open(filename, 'a') do |file|
    file.puts content
  end
end

unless csv_filename && File.exist?(csv_filename)
  result[:_error] = { msg: 'Ensure csv_filename exist.',
                      kind: 'cheehuan-node_info/file_not_found',
                      details: { csv_filename: csv_filename } }
  result['exit_code'] = 1
  puts result.to_json
  exit 1
end

begin
  converter = ->(header) { header.downcase.tr(' ', '_') }
  csv_data = CSV.read(csv_filename,
                      headers: true,
                      header_converters: converter,
                      converters: :all,
                      encoding: "#{enconding}:utf-8")
  hash_data = csv_data.map { |row| row.to_hash }
rescue StandardError => e
  result[:_error] = { msg: 'Invalid CSV file format.',
                      kind: 'cheehuan-node_info/invalid_csvformat',
                      details: { csv_filename: csv_filename } }
  result['error_data'] = e
  result['exit_code'] = 1
  puts result.to_json
  exit 1
end

if hash_data && hash_data[0] && !hash_data[0].keys.include?(key_field)
  result['out'] = "CSV Header: #{hash_data[0].keys}"
  result[:_error] = { msg:  "key_field #{key_field} not found in CSV header.",
                      kind: 'cheehuan-node_info/missing_keyfield',
                      details: { key_field: key_field } }
  result['exit_code'] = 1
  puts result.to_json
  exit 1
elsif !hash_data.empty?
  write_count = 0
  unchanged_count = 0
  error_count = 0
  proceeded_key_field = []
  changed_key_field = []
  gen_key_field = []
  dup_key_field = []
  err_out = []
  fail_output_file = "#{err_target_dir}/#{feed_type}_#{now.strftime('%Y%m%d%H%m')}.csv"

  result['out'] = { 'csv_header' => hash_data[0].keys }
  result['out']['total_size'] = hash_data.size

  hash_data.each do |d|
    unless d[key_field]
      output_err(fail_output_file, d)
      error_count += 1
      next
    end

    keyfield = if basename == true
                 sanitize_filename(d[key_field].downcase.split('.')[0])
               else
                 sanitize_filename(d[key_field].downcase)
               end

    filename = "#{target_dir}/#{keyfield}~#{feed_type}.json"
    skipped_field.each { |k| d.delete(k) }

    begin
      current_data = JSON.parse(File.read(filename)) if File.file?(filename)
      if multiple == false && proceeded_key_field.include?(keyfield)
        dup_key_field << keyfield
      elsif current_data&.is_a?(Hash) && current_data == d
        unchanged_count += 1
      elsif current_data&.is_a?(Array) && current_data.any? { |h| h == d }
        unchanged_count += 1
      else
        if multiple == true && current_data
          dup_key_field << keyfield
        elsif multiple == false && current_data
          changed_key_field << keyfield
        else
          write_count += 1
        end
        gen_key_field << keyfield
        output(filename, d, multiple)
      end
    rescue StandardError => e
      err_out << "#{keyfield}-#{e}\n"
      output_err(fail_output_file, d)
      error_count += 1
    end

    proceeded_key_field << keyfield
  end

  result['out']['unchanged'] = unchanged_count
  result['out']['changed'] = changed_key_field.size
  result['out']['multiple'] = dup_key_field.size if multiple == true
  result['out']['duplicate'] = dup_key_field.size if multiple == false
  result['out']['error'] = error_count
  result['out']['new'] = write_count

  result['data'] = { 'generated' => gen_key_field }
  result['data']['changed'] = changed_key_field
  result['data']['multiple'] = dup_key_field if !dup_key_field.empty? && multiple == true
  result['data']['duplicate'] = dup_key_field if !dup_key_field.empty? && multiple == false

  unless err_out.empty?
    result[:_error] = { msg:  'error write output file.',
                        kind: 'cheehuan-node_info/unknown',
                        details: { fail_output_file: fail_output_file,
                                   data: err_out } }
  end

  puts result.to_json
end
