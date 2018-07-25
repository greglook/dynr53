#!/usr/bin/env ruby

# This script discovers the current IP address(es) of the host and uses them to
# update record sets in the AWS Route53 service.
#
# This expects the AWS credentials to be present in the environment:
#
#     export AWS_ACCESS_KEY_ID='...'
#     export AWS_SECRET_ACCESS_KEY='...'
#
# Author:: Greg Look

require 'ipaddr'
require 'optparse'

require 'aws-sdk-core'
require 'system/getifaddrs'


##### CONFIGURATION #####

$hosted_zone = nil
$domain_name = %x{hostname --fqdn}.strip
$ipv4_interfaces = []
$ipv6_interfaces = []

$ttl = 300
$create_records = true
$await_propagation = true

$verbose = false

# Parse command-line options.
options = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($0)} [options] <hosted zone id>"
  opts.separator ""
  opts.separator "Network options:"
  opts.on('-f', '--fqdn HOSTNAME',  "Set the fully-qualified domain name to update (default: #{$domain_name})") {|n| $domain_name = n }
  opts.on('-4', '--ipv4 INTERFACE', "Update A records for the IPv4 address on an interface") {|iface| $ipv4_interfaces << iface }
  opts.on('-6', '--ipv6 INTERFACE', "Update AAAA records for global IPv6 addresses on an interface") {|iface| $ipv6_interfaces << iface }
  opts.separator ""
  opts.separator "DNS record options:"
  opts.on('-t', '--ttl SECONDS',    "Set the time-to-live of the updated records (default: #{$ttl})") {|t| $ttl = t.to_i }
  opts.on('-c', '--[no-]create',    "Create DNS records if they do not exist (default: #{$create_records})") {|v| $create_records = v }
  opts.on('-w', '--[no-]wait',      "Wait for records to propagate before exiting (default: #{$await_propagation})") {|v| $await_propagation = v }
  opts.separator ""
  opts.separator "General options:"
  opts.on('-v', '--verbose',        "Display status output about the script operations") { $verbose = true }
  opts.on('-h', '--help',           "Display usage information") { print opts; exit }
end
options.parse!

def fail(msg, code=1)
  STDERR.puts(msg)
  exit code
end

def log(msg)
  puts msg if $verbose
end

def log_header(msg)
  log "\n#{msg}"
end

fail options if ARGV.empty?
$hosted_zone = ARGV.shift

fail "Must specify at least one interface to check using --ipv4 or --ipv6" if $ipv4_interfaces.empty? && $ipv6_interfaces.empty?

$domain_name << '.'

log "Dynr53 run #{Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")}"


##### IP ADDRESS DISCOVERY #####

IPV4_PRIVATE_CLASS_A = IPAddr.new("10.0.0.0/8")
IPV4_PRIVATE_CLASS_B = IPAddr.new("172.16.0.0/12")
IPV4_PRIVATE_CLASS_C = IPAddr.new("192.168.0.0/16")

IPV6_UNIQUE_LOCAL = IPAddr.new("fc00::/7")
IPV6_SITE_LOCAL   = IPAddr.new("fec0::/16")
IPV6_LINK_LOCAL   = IPAddr.new("fe80::/16")

def global_ipv4?(address)
  address.ipv4? &&
    !IPV4_PRIVATE_CLASS_A.include?(address) &&
    !IPV4_PRIVATE_CLASS_B.include?(address) &&
    !IPV4_PRIVATE_CLASS_C.include?(address)
end

def global_ipv6?(address)
  address.ipv6? &&
    !IPV6_UNIQUE_LOCAL.include?(address) &&
    !IPV6_SITE_LOCAL.include?(address) &&
    !IPV6_LINK_LOCAL.include?(address)
end

$ipv4_addresses = []
$ipv6_addresses = []

log_header "Discovering global IP addresses..."
System.get_all_ifaddrs.each do |info|
  interface = info[:interface]
  address = info[:inet_addr]

  if $ipv4_interfaces.include?(interface) && global_ipv4?(address)
    log "    #{interface}: #{address}"
    $ipv4_addresses << address
  elsif $ipv6_interfaces.include?(interface) && global_ipv6?(address)
    log "    #{interface}: #{address}"
    $ipv6_addresses << address
  end
end

$ipv4_addresses.sort!
$ipv6_addresses.sort!


##### RECORD QUERYING #####

log_header "Connecting to AWS Route53 service..."
$route53 = Aws::Route53.new(region: 'us-west-2')

log "Querying Route53 for resource record sets for #{$domain_name}.."
response = $route53.list_resource_record_sets(hosted_zone_id: $hosted_zone, start_record_name: $domain_name)

record_sets = response.resource_record_sets.reject {|set| set.name != $domain_name }
$ipv4_record = nil
$ipv6_record = nil

record_sets.each do |set|
  if set.type == 'A'
    $ipv4_record = set.resource_records.map{|v| IPAddr.new(v.value) }.sort
    log "     A record: #{$ipv4_record.join(', ')} (ttl #{set.ttl})"
  elsif set.type == 'AAAA'
    $ipv6_record = set.resource_records.map{|v| IPAddr.new(v.value) }.sort
    log "     AAAA record: #{$ipv6_record.join(', ')} (ttl #{set.ttl})"
  end
end



##### RECORD UPDATING #####

$updates = []

def update_record(type, record, addresses)
  if record.nil?
    # Nothing to do
    return if addresses.empty?

    # Needs creating.
    if $create_records
      log "    #{type} record missing, creating => #{addresses.join(', ')}"
    else
      log "    #{type} record missing, not creating"
      return
    end
  else
    # Nothing to do.
    return if record == addresses

    if addresses.empty?
      log "    #{type} record present but no addresses found! skipping"
      return
    else
      # Needs updating.
      log "    #{type} record needs updating => #{addresses.join(', ')}"
    end
  end

  $updates << {
    action: 'UPSERT',
    resource_record_set: {
      name: $domain_name,
      type: type,
      ttl: $ttl,
      resource_records: addresses.map do |addr|
        {value: addr.to_s}
      end
    }
  }
end

log_header "Determining action..."
update_record('A',    $ipv4_record, $ipv4_addresses)
update_record('AAAA', $ipv6_record, $ipv6_addresses)

if $updates.empty?
  log "    No updates required"
  exit
end

log_header "Applying updates to Route53..."
request = {
  hosted_zone_id: $hosted_zone,
  change_batch: {
    comment: "Dynr53 automatic update",
    changes: $updates
  }
}

response = $route53.change_resource_record_sets(request)

change_id = response.change_info.id.split('/')[2]
status = response.change_info.status
log "    Submitted change #{change_id} (#{response.change_info.status})"

# Wait for any changes to succeed.
if $await_propagation
  max_retries = 6
  retry_period = 10

  attempt = 0
  while status == 'PENDING' && attempt < max_retries
    attempt += 1
    sleep retry_period
    response = $route53.get_change(id: change_id)
    status = response.change_info.status
    log "    %d: %s%s" % [attempt, status, status == 'PENDING' ? '...' : '']
  end

  fail "Gave up after #{attempt * retry_period} seconds" if status != 'INSYNC'
end
