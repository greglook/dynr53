Dynr53
======

This is a ruby script to update AWS Route53 with records based on the current
addresses of specified interfaces. In short, this allows a cron job running on a
router to provide dynamic DNS service for a home network.

## Usage

Add your AWS credentials to the environment and call `update-routes` with the
interfaces and the id of the hosted zone in which to update the domain:

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...

./update-routes.rb -4 wan0 -6 br0 Z2BMQOXB5L6338
```

For more options, try:

```bash
./update-routes.rb --help
```
