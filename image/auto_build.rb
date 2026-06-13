require 'pty'
require 'optparse'

images = {
  base_deps_amd64: {
    name: 'base',
    tag: 'discourse/base:build_deps_amd64',
    extra_args: '--target discourse-build-base'
  },
  base_deps_arm64: {
    name: 'base',
    tag: 'discourse/base:build_deps_arm64',
    extra_args: '--platform linux/arm64 --target discourse-build-base'
  },
  base_slim_main_amd64: {
    name: 'base',
    tag: 'discourse/base:build_slim_main_amd64',
    extra_args: '--target discourse-slim',
    use_cache: true
  },
  base_slim_stable_amd64: {
    name: 'base',
    tag: 'discourse/base:build_slim_main_amd64',
    extra_args: '--target discourse-slim --build-arg="DISCOURSE_BRANCH=stable"',
    use_cache: true
  },
  base_slim_main_arm64: {
    name: 'base',
    tag: 'discourse/base:build_slim_main_arm64',
    extra_args: '--platform linux/arm64 --target discourse-slim',
    use_cache: true
  },
  base_slim_stable_arm64: {
    name: 'base',
    tag: 'discourse/base:build_slim_stable_arm64',
    extra_args:
      '--platform linux/arm64 --target discourse-slim --build-arg="DISCOURSE_BRANCH=stable"',
    use_cache: true
  },
  base_web_only_main_amd64: {
    name: 'base',
    tag: 'discourse/base:build_web_only_main_amd64',
    extra_args: '--target discourse-web-only',
    use_cache: true
  },
  base_web_only_stable_amd64: {
    name: 'base',
    tag: 'discourse/base:build_web_only_stable_amd64',
    extra_args:
      '--target discourse-web-only --build-arg="DISCOURSE_BRANCH=stable"',
    use_cache: true
  },
  base_web_only_main_arm64: {
    name: 'base',
    tag: 'discourse/base:build_web_only_main_arm64',
    extra_args: '--platform linux/arm64 --target discourse-web-only',
    use_cache: true
  },
  base_web_only_stable_arm64: {
    name: 'base',
    tag: 'discourse/base:build_web_only_stable_arm64',
    extra_args:
      '--platform linux/arm64 --target discourse-web-only --build-arg="DISCOURSE_BRANCH=stable"',
    use_cache: true
  },
  base_release_main_amd64: {
    name: 'base',
    tag: 'discourse/base:build_release_main_amd64',
    extra_args:
      '--build-arg="DISCOURSE_BRANCH=main" --target discourse-release',
    use_cache: true
  },
  base_release_main_arm64: {
    name: 'base',
    tag: 'discourse/base:build_release_main_arm64',
    extra_args:
      '--platform linux/arm64 --build-arg="DISCOURSE_BRANCH=main" --target discourse-release',
    use_cache: true
  },
  base_release_stable_amd64: {
    name: 'base',
    tag: 'discourse/base:build_release_stable_amd64',
    extra_args:
      '--build-arg="DISCOURSE_BRANCH=stable" --target discourse-release',
    use_cache: true
  },
  base_release_stable_arm64: {
    name: 'base',
    tag: 'discourse/base:build_release_stable_arm64',
    extra_args:
      '--platform linux/arm64 --build-arg="DISCOURSE_BRANCH=stable" --target discourse-release',
    use_cache: true
  },
  discourse_test_build_amd64: {
    name: 'discourse_test',
    tag: 'discourse/discourse_test:build_amd64',
    extra_args: '--build-arg="from_tag=build_release_main_amd64"'
  },
  discourse_test_build_arm64: {
    name: 'discourse_test',
    tag: 'discourse/discourse_test:build_arm64',
    extra_args:
      '--platform linux/arm64 --build-arg="from_tag=build_release_main_arm64"'
  },
  discourse_dev_amd64: {
    name: 'discourse_dev',
    tag: 'discourse/discourse_dev:build_amd64',
    extra_args: '--build-arg="from_tag=build_slim_main_amd64"'
  },
  discourse_dev_arm64: {
    name: 'discourse_dev',
    tag: 'discourse/discourse_dev:build_arm64',
    extra_args:
      '--platform linux/arm64 --build-arg="from_tag=build_slim_main_arm64"'
  },
  setup_wizard_amd64: {
    name: 'setup_wizard',
    tag: 'discourse/setup-wizard:build_amd64',
    extra_args: ''
  },
  setup_wizard_arm64: {
    name: 'setup_wizard',
    tag: 'discourse/setup-wizard:build_arm64',
    extra_args: '--platform linux/arm64'
  }
}

def run(command)
  lines = []
  PTY.spawn(command) do |stdout, _stdin, pid|
    begin
      stdout.each do |line|
        lines << line
        puts line
      end
    rescue Errno::EIO
      # we are done
    end
    Process.wait(pid)
  end

  raise "'#{command}' exited with status #{$?.exitstatus}" if $?.exitstatus != 0

  lines
end

# Registry-backed BuildKit layer cache, so cold builders (fresh CI runners)
# reuse compiled artifacts (imagemagick, vips, nginx, ...) instead of
# recompiling them. mode=max exports intermediate stages too; entries are
# content-addressed so integrity comes with the digest.
#
# DISCOURSE_BUILD_CACHE_FROM_REF: registry ref to read cache from
# DISCOURSE_BUILD_CACHE_TO_REF:   registry ref to write cache to (needs push
#                                 access; pushing replaces the tag, so use one
#                                 ref per platform or amd64/arm64 evict each
#                                 other)
# Typical CI shape: PRs read only, pushes read+write, the nightly scheduled
# build writes only — keeping the nightly a full cold rebuild so published
# images always carry that day's apt security updates.
def cache_args(image)
  return '' if image[:use_cache] != true

  args = []
  from_ref = ENV['DISCOURSE_BUILD_CACHE_FROM_REF']
  to_ref = ENV['DISCOURSE_BUILD_CACHE_TO_REF']
  args << "--cache-from type=registry,ref=#{from_ref}" if from_ref && !from_ref.empty?
  args << "--cache-to type=registry,ref=#{to_ref},mode=max" if to_ref && !to_ref.empty?
  args.join(' ')
end

def build(image, cli_args)
  # /VERSION must reflect the build date even when the layer comes from
  # cache, so the date is passed in as a cache-busting build-arg
  version_date_arg = "--build-arg VERSION_DATE=#{Time.now.strftime('%Y%m%d')}"
  lines =
    run(
      "cd #{image[:name]} && docker buildx build . --load #{image[:use_cache] == true ? '' : '--no-cache'} #{cache_args(image)} #{version_date_arg} --tag #{image[:tag]} #{image[:extra_args] || ''} #{cli_args}"
    )

  return unless lines[-1] =~ /successfully built/

  raise "Error building the image for #{image[:name]}: #{lines[-1]}"
end

def dev_deps
  run(
    "sed -e 's/\(db_name: discourse\)/\1_development/' ../templates/postgres.template.yml > discourse_dev/postgres.template.yml"
  )
  run('cp ../templates/redis.template.yml discourse_dev/redis.template.yml')
end

if ARGV.length == 0
  puts <<~TEXT
    Usage:
    ruby auto_build.rb IMAGE

    Available images:
    #{images.keys.join(', ')}
  TEXT
  exit 1
else
  image = ARGV[0].to_sym

  unless images.include?(image)
    warn 'Image not found'
    exit 1
  end

  puts "Building #{images[image]}"
  dev_deps if %i[discourse_dev_amd64 discourse_dev_arm64].include?(image)

  build(images[image], ARGV[1..-1].join(' '))
end
