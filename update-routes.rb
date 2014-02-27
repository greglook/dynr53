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

require 'aws-sdk-core'
require 'optparse'


$hosted_zone = nil
$domain_name = %x{hostname --fqdn}
$ipv4 = true
$ipv6 = true

# Parse command-line options.
options = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($0)} [options] <hosted zone id>"
  opts.on('-f', '--fqdn HOSTNAME', "Sets the fully-qualified domain name to update (default: #{$domain_name})") {|n| $domain_name = n }
  opts.on('-4', '--[no-]ipv4', "Updates A records for public IPv4 addresses (default: #{$ipv4})") {|v| $ipv4 = v }
  opts.on('-6', '--[no-]ipv6', "Updates AAAA records for global IPv6 addresses (default: #{$ipv6})") {|v| $ipv6 = v }
  opts.on('-h', '--help', "Displays usage information") { print opts; exit }
end

def fail(msg, code=1)
  STDERR.puts(msg)
  exit code
end

fail opts if ARGV.empty?
$hosted_zone = ARGV.shift

# Discover ip addresses.

route53 = Aws::Route53.new()

# Query R53 for existing records
response = route53.list_resource_record_sets(hosted_zone_id: $hosted_zone)
resp.resource_record_sets

# Update R53 if necessary.

# Wait for any changes to succeed.
