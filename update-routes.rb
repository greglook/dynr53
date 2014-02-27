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


$hosted_zone = nil
$domain_name = %x{hostname --fqdn}.strip
$ipv4 = []
$ipv6 = []

# Parse command-line options.
options = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($0)} [options] <hosted zone id>"
  opts.on('-f', '--fqdn HOSTNAME', "Sets the fully-qualified domain name to update (default: #{$domain_name})") {|n| $domain_name = n }
  opts.on('-4', '--ipv4 IFACE', "Updates A records for the IPv4 address on an interface") {|iface| $ipv4 << iface }
  opts.on('-6', '--ipv6 IFACE', "Updates AAAA records for global IPv6 addresses on an interface") {|iface| $ipv6 << iface }
  opts.on('-h', '--help', "Displays usage information") { print opts; exit }
end
options.parse!

def fail(msg, code=1)
  STDERR.puts(msg)
  exit code
end

fail options if ARGV.empty?
$hosted_zone = ARGV.shift


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

$addresses = {}

System.get_all_ifaddrs.each do |info|
  interface = info[:interface]
  address = info[:inet_addr]
  netmask = info[:netmask]

  if $ipv4.include?(interface) && global_ipv4?(address)
    # TODO: handle IPv4 address
    puts "IPv4 #{interface} #{address}"
  elsif $ipv6.include?(interface) && global_ipv6?(address)
    # TODO: handle IPv6 address
    puts "IPv6 #{interface} #{address}"
  end
end

#route53 = Aws::Route53.new()

# Query R53 for existing records
#response = route53.list_resource_record_sets(hosted_zone_id: $hosted_zone)
#resp.resource_record_sets

# Update R53 if necessary.

# Wait for any changes to succeed.
