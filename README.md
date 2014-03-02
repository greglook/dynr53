Dynr53
======

This is a ruby script to update AWS Route53 with records based on the current
addresses of specified interfaces. In short, this allows a cron job running on a
router to provide dynamic DNS service for a home network.

In my case, I have a router with `wan0` connected to the internet and some
lan and wireless interfaces bridged via `br0`. I want to update my host's DNS
records to point to the public IPv4 address given to me by my ISP, and to the
global IPv6 address on my subnet.

## Usage

Add your AWS credentials to the environment and call `update-routes.rb` with
the interfaces and the id of the hosted zone in which to update the domain:

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...

./update-routes.rb -4 wan0 -6 br0 Z2BMQOXB5L6338
```

The script accepts a number of options to control its behavior:

* `-f` `--fqdn HOSTNAME`
  Set the fully-qualified domain name to update records for. This defaults to
  the output of `hostname --fqdn`.
* `-4` `--ipv4 INTERFACE`
  Specify a network interface to check for public IPv4 addresses.
* `-6` `--ipv6 INTERFACE`
  Specify a network interface to check for global IPv6 addresses.
* `-t` `--ttl SECONDS`
  Set the time-to-live of created records, in seconds.
* `-c` `--[no-]create`
  Controls whether missing DNS records will be created or ignored.
* `-w` `--[no-]wait`
  Causes the script to wait for full change propagation before exiting.

At least one network interface must be specified, and the id of the hosted zone
to update must be given as the first non-option argument.

## Output

By default, the script produces no output since it is intended to run as a cron
job. However, with the `--verbose` option the script reports what it's doing as
it goes:

```
Dynr53 run 2014-03-02T19:35:02Z

Discovering global IP addresses...
    wan0: 198.245.101.200
    br0: 2001:471:b:253::1

Connecting to AWS Route53 service...
Querying Route53 for resource record sets for example.domain.tld...
     A record: 198.245.101.200 (ttl 300)

Determining action...
    AAAA record missing, creating => 2001:471:b:253::1

Applying updates to Route53...
    Submitted change C2GP48YM36SK76 (PENDING)
    1: PENDING...
    2: PENDING...
    3: PENDING...
    4: INSYNC
```
