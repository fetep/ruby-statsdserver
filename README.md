## Overview

`statsd` is a graphite frontend that aggregates data.  For more information,
see [an Etsy blog post](http://codeascraft.etsy.com/2011/02/15/measure-anything-measure-everything/)
introducing the statsd concept.

## Protocol

see PROTOCOL.md. It's basically compatible with all of the other major
statsd implementations of `timers` and `counters`.

## Features

* supports standard UDP input (timers + counters)
* supports zeromq input (for high throughput applications)
* supports multi-value timer updates (for clients that want to do some aggregating of update messages)
* supports amqp output (helpful if you want >1 consumer of the stats stream)

### Inputs

* UDP
* ZeroMQ (push/pull sockets)

### Outputs

* stdout (useful for debugging)
* tcp (e.g. to carbon)
* amqp

#### AMQP notes

This has had a lot of run time in production against a RabbitMQ server,
publishing to a topic exchange. If you have run other configurations
successfully, please drop me a line and I'll note them here.

If you are using AMQP as a transport for graphite metrics to carbon,
this implementation of statsd sends metrics in the body name (not as
the routing key), so make sure your carbon configuration has:

  `AMQP_METRIC_NAME_IN_BODY = True`

## Config File

[An example config file](https://github.com/fetep/ruby-statsdserver/blob/master/etc/statsd.conf)
is included, along with comments about each option.

## Run-time

Please don't run statsd as root.

### daemontools / runit

Make sure `daemonize` is set to `false` in the config file, and in
your run file, drop privs and run statsd:

```
#!/bin/sh

user="statsd"
config="/etc/statsd.conf"

su $user -c "exec /usr/bin/statsd $config"
```

### init.d script

TODO. Probably should add pidfile support, too.
