require 'json'
require 'facter'
require 'find'
require 'time'

Puppet::Functions.create_function(:node_info) do
  dispatch :node_info do
    param 'String', :certname
    optional_param 'Optional[String]', :last_updated
  end

  def node_info_target_dir(node_info_source)
    return unless File.file?(node_info_source)
    node_target_dir = File.foreach(node_info_source).grep(%r{target_dir})
    node_target_dir[0].split(':')[1].lstrip unless node_target_dir.empty?
  end

  # load file content and merge into single node_info hash bases on file_nameing <certname>_<feed_type>.<file_format> e.g mom.vm_cmdb.json
  def node_info(certname, last_updated)
    node_info_path = '/var/puppetlabs/data/node_info/validated'
    # node_info_path = node_info_target_dir('/etc/puppetlabs/facter/facts.d/node_info_source.yaml')
    node_info = {}

    node_info_files = Dir.glob("#{node_info_path}/#{certname}~*")
    return node_info if node_info_files.empty?

    if last_updated
      agent_last_updated = Time.parse(last_updated)
      source_last_updated = node_info_files.map { |f| [File.mtime(f)] }.sort.last[0]
      return node_info if agent_last_updated > source_last_updated
    end

    node_filename_pattern = %r{^(?<filename>[^~]+)~(?<feed_type>[^.]+).(?<file_type>\w+)}
    node_info_files.each do |node_filename|
      file_data = node_filename_pattern.match(node_filename)
      unless file_data
        Puppet.warning "node_info: #{node_filename} invalid filename pattern"
        next
      end
      begin
        if file_data[:file_type] == 'json'
          file_data_hash = JSON.parse(File.read(node_filename))
        elsif file_data[:file_type] == 'yaml'
          file_data_hash = YAML.safe_load(File.read(node_filename))
        end
      rescue Exception => e # rubocop:disable Lint/RescueException
        Puppet.warning "node_info: unable to parse data #{e}"
        file_data_hash = {}
      end
      node_info[file_data[:feed_type]] = file_data_hash
    end
    node_info
  end
end
