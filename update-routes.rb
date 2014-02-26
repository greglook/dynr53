#!/usr/bin/env ruby

# This script discovers the current IP address(es) of the host and uses them to
# update record sets in the AWS Route53 service.
#
# Author:: Greg Look

require 'optparse'


aws_access_key_id = nil
aws_secret_access_key = nil
aws_region = 'us-west-2'

domain_name = %x{hostname --fqdn}


# 1. parse environment/arguments and initialize config
# 2. discover ip addresses
# 3. query R53 for existing records
# 4. update R53 if necessary
# 5. wait for any changes to succeed
