require 'statsd-ruby'
require 'docker'

$statsd = Statsd.new '10.0.0.1', 8125

module Docker
  class CloseConnectionError < StandardError; end
  class Container
    def name
      info['Names'].first[1..-1]
    end

    def stats
      path = path_for(:stats)

      result = nil

      streamer = lambda do |chunk, _remaining, _total|
        result ||= chunk
        raise CloseConnectionError if result
      end
      options = { response_block: streamer }.merge(connection.options)

      Excon.get(connection.url + path[1..-1], options) rescue CloseConnectionError

      Docker::Util.parse_json(result)
    end
  end
end

def median(array)
  sorted = array.sort
  len = sorted.length
  ((sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0).to_i
end

def analyze_container(container)
  data = container.exec(['ps', '-eo', 'rss,args'])[0].join("\n").split("\n")
  unicorns = data.grep(/unicorn/).map(&:to_i)
  sidekiqs = data.grep(/sidekiq/).map(&:to_i)

  result = {}

  unless unicorns.empty?
    result['unicorn.max_rss'] = unicorns.max
    result['unicorn.median_rss'] = median(unicorns)
  end

  unless sidekiqs.empty?
    result['sidekiq.max_rss'] = sidekiqs.max
    result['sidekiq.median_rss'] = median(sidekiqs)
  end
  result['total_mem_usage'] = container.stats['memory_stats']['usage']

  @prev_stats ||= {}
  prev_stats = @prev_stats[container.name]
  @prev_stats[container.name] = stats = container.stats

  if prev_stats
    cpu_delta = stats['cpu_stats']['system_cpu_usage'] - prev_stats['cpu_stats']['system_cpu_usage']
    app_cpu_delta = stats['cpu_stats']['cpu_usage']['total_usage'] - prev_stats['cpu_stats']['cpu_usage']['total_usage']

    result['cpu_usage'] = (app_cpu_delta.to_f / cpu_delta.to_f) * stats['cpu_stats']['cpu_usage']['percpu_usage'].length * 100.0
  end

  result
end

def containers
  Docker::Container.all
end

hostname = Docker.info['Name']

STDERR.puts "#{Time.now} Starting Monitor"

loop do
  begin
    containers.each do |c|
      analyze_container(c).each do |k, v|
        if v && v > 0
          $statsd.gauge "#{hostname}.#{c.name}.#{k}", v
        end
      end
    end
  rescue => e
    STDERR.puts e
    STDERR.puts e.backtrace
  end

  sleep 60
end
