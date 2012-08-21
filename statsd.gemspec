Gem::Specification.new do |spec|
  files = []
  dirs = %w(lib)
  dirs.each do |dir|
    files += Dir["#{dir}/**/*"]
  end

  spec.name = "statsdserver"
  spec.version = "0.6pre"
  spec.summary = "statsd (server) -- stat collector/aggregator"
  spec.description = "collect and aggregate stats, flush to graphite"
  spec.license = "Apache License 2.0"

  spec.add_dependency("bundler")

  spec.add_development_dependency("rspec")

  spec.add_runtime_dependency("daemons")
  spec.add_runtime_dependency("eventmachine")
  spec.add_runtime_dependency("parseconfig")
  spec.add_runtime_dependency("sysexits")

  # Optional dependencies
  spec.add_development_dependency("bunny")      # AMQP output support
  spec.add_development_dependency("em-zeromq")  # ZeroMQ input support

  spec.files = files
  spec.require_paths << "lib"
  spec.bindir = "bin"
  spec.executables << "statsd"

  spec.author = "Pete Fritchman"
  spec.email = "petef@databits.net"
  spec.homepage = "https://github.com/fetep/ruby-statsd"
end
