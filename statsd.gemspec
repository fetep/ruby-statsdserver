Gem::Specification.new do |spec|
  files = []
  dirs = %w(lib)
  dirs.each do |dir|
    files += Dir["#{dir}/**/*"]
  end

  spec.name = "petef-statsd"
  spec.version = "0.5"
  spec.summary = "statsd -- stat collector/aggregator"
  spec.description = "collect and aggregate stats, flush to graphite"
  spec.license = "Mozilla Public License (1.1)"

  spec.add_dependency("eventmachine")
  spec.add_dependency("amqp")

  spec.files = files
  spec.require_paths << "lib"
  spec.bindir = "bin"
  spec.executables << "statsd"

  spec.author = "Pete Fritchman"
  spec.email = "petef@databits.net"
  spec.homepage = "https://github.com/fetep/ruby-statsd"
end
