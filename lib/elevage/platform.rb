# rubocop:disable LineLength
require 'yaml'
require 'resolv'
require 'English'

module Elevage
  # Platform class
  class Platform
    attr_accessor :name, :description
    attr_accessor :environments
    attr_accessor :tiers
    attr_accessor :nodenameconvention
    attr_accessor :pools
    attr_accessor :components
    attr_accessor :vcenter
    attr_accessor :network
    attr_accessor :compute

    # rubocop:disable MethodLength
    def initialize
      fail unless platform_files_exists?
      platform = YAML.load_file(YML_PLATFORM).fetch('platform')
      @name = platform['name']
      @description = platform['description']
      @environments = platform['environments']
      @tiers = platform['tiers']
      @nodenameconvention = platform['nodenameconvention']
      @pools = platform['pools']
      @components = platform['components']
      @vcenter = YAML.load_file(YML_VCENTER).fetch('vcenter')
      @network = YAML.load_file(YML_NETWORK).fetch('network')
      @compute = YAML.load_file(YML_COMPUTE).fetch('compute')
    end
    # rubocop:enable MethodLength

    # rubocop:disable MethodLength
    def healthy?
      health = ''
      health += MSG[:empty_environments] unless @environments.all?
      health += MSG[:empty_tiers] unless @tiers.all?
      health += MSG[:empty_nodenameconvention] unless @nodenameconvention.all?
      health += health_pools + health_vcenter + health_network + health_compute
      if health.length > 0
        puts health + "\n#{health.lines.count} platform offense(s) detected"
        false
      else
        true
      end
    end
    # rubocop:enable MethodLength

    private

    def health_compute
      health = ''
      @compute.each do |_compute, v|
        health += MSG[:invalid_cpu] unless (0..CPU_LIMIT).member?(v['cpu'])
        health += MSG[:invalid_ram] unless (0..RAM_LIMIT).member?(v['ram'])
      end
      health
    end

    # rubocop:disable AmbiguousOperator
    def health_network
      health = ''
      @network.each do |_network, v|
        puts v
        health += MSG[:empty_network] if v.values.any? &:nil?
        health += MSG[:invalid_gateway] unless Resolv::IPv4::Regex.match(v['gateway'])
      end
      health
    end
    # rubocop:enable AmbiguousOperator

    # rubocop:disable MethodLength, LineLength, CyclomaticComplexity, PerceivedComplexity
    def health_vcenter
      health = ''
      @vcenter.each do |_vcenter, v|
        health += MSG[:invalid_geo] if v['geo'].nil?
        health += MSG[:invalid_timezone] unless (0..TIMEZONE_LIMIT).member?(v['timezone'].to_i)
        health += MSG[:invalid_host] unless valid_vcenter_host?(v['host'])
        health += MSG[:invalid_datacenter] if v['datacenter'].nil?
        health += MSG[:invalid_imagefolder] if v['imagefolder'].nil?
        health += MSG[:invalid_destfolder] if v['destfolder'].nil?
        health += MSG[:invalid_appendenv] unless v['appendenv'] == true || v['appendenv'] == false
        health += MSG[:invalid_appenddomain] unless v['appenddomain'] == true || v['appenddomain'] == false
        health += MSG[:empty_datastores] unless v['datastores'].all?
        health += MSG[:invalid_domain] if v['domain'].nil?
        v['dnsips'].each { |ip| health += MSG[:invalid_ip] unless Resolv::IPv4::Regex.match(ip) }
      end
      health
    end
    # rubocop:enable MethodLength, LineLength, CyclomaticComplexity, PerceivedComplexity

    # rubocop:disable MethodLength, LineLength, CyclomaticComplexity, PerceivedComplexity
    def health_pools
      health = ''
      @pools.each do |_pool, v|
        health += MSG[:pool_count_size] unless (0..POOL_LIMIT).member?(v['count'])
        health += MSG[:invalid_tiers] unless @tiers.include?(v['tier'])
        health += MSG[:no_image_ref] if v['image'].nil?
        health += MSG[:invalid_compute] unless @compute.key?(v['compute'])
        health += MSG[:invalid_port] if v['port'].nil?
        health += MSG[:invalid_runlist] unless v['runlist'].all?
        health += MSG[:invalid_componentrole] unless v['componentrole'].include?('#') if v['componentrole']
      end
      health
    end
    # rubocop:enable MethodLength, LineLength, CyclomaticComplexity, PerceivedComplexity

    # Private: confirms existence of the standard platform defintion files
    # Returns true if all standard files present
    def platform_files_exists?
      fail(IOError, ERR[:no_platform_file]) unless File.file?(YML_PLATFORM)
      fail(IOError, ERR[:no_vcenter_file]) unless File.file?(YML_VCENTER)
      fail(IOError, ERR[:no_network_file]) unless File.file?(YML_NETWORK)
      fail(IOError, ERR[:no_compute_file]) unless File.file?(YML_COMPUTE)
      true
    end

    # Private: given a url or ip check for access
    # Returns true/false based on simple ping check
    def valid_vcenter_host?(address)
      _result = `ping -q -c 3 #{address}`
      $CHILD_STATUS.exitstatus == 0 ? true : false
      true
    end
  end
end
# rubocop:enable LineLength
