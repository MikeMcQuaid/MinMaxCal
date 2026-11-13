# Manage TestFlight distribution without third-party dependencies.
require 'base64'
require 'fileutils'
require 'json'
require 'net/http'
require 'openssl'
require 'time'

class TestFlight
  UPLOAD_RECORD = '.test-scratch/testflight-upload.json'
  PUBLIC_ARTIFACT = /\Atestflight-(upload|attempt)-([0-9]+(?:\.[0-9]+){0,2})(?:-[0-9]+)?\z/

  def self.check_release_limit(releases, now = Time.now)
    count = releases.count do |release|
      !release['draft'] && release['published_at'] && Time.iso8601(release['published_at']) > now - 86_400
    end
    raise 'Already published three releases in the past 24 hours; wait before retrying.' if count >= 3
  end

  def self.record_public
    FileUtils.mkdir_p(File.dirname(UPLOAD_RECORD))
    File.write(UPLOAD_RECORD, JSON.generate(ENV.to_h.slice('BUILD_NUMBER', 'RELEASE_VERSION', 'GITHUB_SHA', 'GITHUB_RUN_ID')))
  end

  def self.resume_public
    record = JSON.parse(File.read(UPLOAD_RECORD))
    unless %w[RELEASE_VERSION GITHUB_SHA GITHUB_RUN_ID].all? { |key| record.fetch(key) == ENV.fetch(key) }
      raise 'The saved TestFlight upload does not match this release, commit or workflow run'
    end
    number = record.fetch('BUILD_NUMBER')
    raise 'Invalid saved build number' unless number.match?(/\A[0-9]+(?:\.[0-9]+){0,2}\z/)
    number
  end

  def self.github_pages(path)
    output = IO.popen(['gh', 'api', '--paginate', '--slurp', "repos/#{ENV.fetch('GITHUB_REPOSITORY')}/#{path}"], &:read)
    raise 'Could not read GitHub release history' unless $?.success?
    JSON.parse(output)
  end

  def public_artifacts
    self.class.github_pages('actions/artifacts?per_page=100').flat_map { |page| page.fetch('artifacts') }.select do |artifact|
      run = artifact.fetch('workflow_run')
      artifact.fetch('name').match?(PUBLIC_ARTIFACT) && run.fetch('head_branch') == 'main' &&
        run.fetch('head_repository_id') == run.fetch('repository_id')
    end
  end

  def build_uploads
    list("/v1/apps/#{@app.fetch('id')}/buildUploads").select { |upload| upload.dig('attributes', 'platform') == 'IOS' }
  end

  def initialize
    @key = OpenSSL::PKey.read(ENV.fetch('APP_STORE_KEY'))
    apps = list('/v1/apps', 'filter[bundleId]' => 'com.mikemcquaid.MinMaxCal')
    raise 'Expected one MinMaxCal App Store Connect record' unless apps.length == 1
    @app = apps.first
  end

  def request(method, path, body = nil)
    uri = URI.join('https://api.appstoreconnect.apple.com', path)
    unless uri.scheme == 'https' && uri.host == 'api.appstoreconnect.apple.com' && uri.port == 443
      raise 'Unexpected App Store Connect pagination URL'
    end
    now = Time.now.to_i
    token = [
      { alg: 'ES256', kid: ENV.fetch('APP_STORE_KEY_ID'), typ: 'JWT' },
      { iss: ENV.fetch('APP_STORE_ISSUER_ID'), iat: now, exp: now + 600, aud: 'appstoreconnect-v1' }
    ].map { |part| Base64.urlsafe_encode64(JSON.generate(part), padding: false) }.join('.')
    # JWT uses fixed-width r and s, rather than OpenSSL's DER encoding.
    signature = OpenSSL::ASN1.decode(@key.sign('SHA256', token)).value.map do |integer|
      [integer.value.to_s(16).rjust(64, '0')].pack('H*')
    end.join
    req = Net::HTTPGenericRequest.new(method, !body.nil?, true, uri.request_uri)
    req['Authorization'] = "Bearer #{token}.#{Base64.urlsafe_encode64(signature, padding: false)}"
    req['Content-Type'] = 'application/json'
    req.body = JSON.generate(body) if body
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 30, read_timeout: 60) do |http|
      http.request(req)
    end
    unless response.is_a?(Net::HTTPSuccess)
      raise "App Store Connect #{method} #{uri.path}: HTTP #{response.code}: #{response.body}"
    end
    response.body.to_s.empty? ? {} : JSON.parse(response.body)
  end

  def list(path, query = {})
    path = "#{path}?#{URI.encode_www_form(query.merge('limit' => 200))}"
    records = []
    while path
      page = request('GET', path)
      records.concat(page.fetch('data'))
      path = page.dig('links', 'next')
    end
    records
  end

  def builds(query = {})
    list('/v1/builds', {
      'filter[app]' => @app.fetch('id'), 'filter[preReleaseVersion.platform]' => 'IOS',
      'sort' => '-uploadedDate'
    }.merge(query))
  end

  def next_build_number
    versions = builds.map { |build| build.fetch('attributes').fetch('version') }
    versions.concat(build_uploads.map { |upload| upload.fetch('attributes').fetch('cfBundleVersion') })
    versions.concat(public_artifacts.map { |artifact| PUBLIC_ARTIFACT.match(artifact.fetch('name'))[2] })
    major = versions.map do |version|
      raise "Invalid Apple build number: #{version.inspect}" unless version.match?(/\A[0-9]+(?:\.[0-9]+){0,2}\z/)
      version.split('.').first.to_i
    end.max || 0
    (major + 1).to_s
  end

  def public_group
    name = ENV['TESTFLIGHT_PUBLIC_GROUP'].to_s
    name = 'Public Beta' if name.empty?
    groups = list("/v1/apps/#{@app.fetch('id')}/betaGroups").select do |group|
      group.dig('attributes', 'name') == name && group.dig('attributes', 'isInternalGroup') == false
    end
    raise "Expected one external group named #{name.inspect}; complete the TestFlight setup." unless groups.length == 1
    groups.first.fetch('id')
  end

  def prepare_public
    public_group
    if builds('filter[preReleaseVersion.version]' => ENV.fetch('RELEASE_VERSION')).any? do |build|
         build.dig('attributes', 'buildAudienceType') == 'APP_STORE_ELIGIBLE'
       end
      raise 'A public build already exists for this version; retry its original workflow or use a new version.'
    end
    check_public_limit
  end

  def check_public_limit
    cutoff = Time.now - 86_400
    public_builds = builds.select { |build| build.dig('attributes', 'buildAudienceType') == 'APP_STORE_ELIGIBLE' }
    artifacts = public_artifacts
    numbers = public_builds.map { |build| build.fetch('attributes').fetch('version') }
    numbers.concat(artifacts.map { |artifact| PUBLIC_ARTIFACT.match(artifact.fetch('name'))[2] })
    accepted = build_uploads.select { |upload| numbers.include?(upload.dig('attributes', 'cfBundleVersion')) }
    recent = accepted.select do |upload|
      attributes = upload.fetch('attributes')
      Time.iso8601(attributes.fetch('createdDate')) > cutoff ||
        (attributes['uploadedDate'] && Time.iso8601(attributes['uploadedDate']) > cutoff)
    end.map { |upload| upload.fetch('attributes').fetch('cfBundleVersion') }
    processed = public_builds.select do |build|
      Time.iso8601(build.fetch('attributes').fetch('uploadedDate')) > cutoff
    end.map { |build| build.fetch('attributes').fetch('version') }
    counts = [recent, processed].map { |items| items.group_by(&:itself).transform_values(&:length) }
    count = counts.flat_map(&:keys).uniq.sum { |number| counts.map { |items| items.fetch(number, 0) }.max }
    # Match each accepted operation to at most one reservation made before it.
    artifacts.select { |artifact| artifact.fetch('name').start_with?('testflight-attempt-') }
             .sort_by { |artifact| artifact.fetch('created_at') }.each do |artifact|
      number = PUBLIC_ARTIFACT.match(artifact.fetch('name'))[2]
      start = Time.iso8601(artifact.fetch('created_at'))
      match = accepted.index do |upload|
        upload.dig('attributes', 'cfBundleVersion') == number &&
          Time.iso8601(upload.fetch('attributes').fetch('createdDate')).between?(start, start + 3600)
      end
      if match
        accepted.delete_at(match)
      elsif start + 3600 > cutoff
        count += 1
      end
    end
    raise 'Already made or reserved three public uploads in the past 24 hours; wait before retrying.' if count >= 3
  end

  def public_upload_needed?
    return false unless builds('filter[version]' => ENV.fetch('BUILD_NUMBER'),
                               'filter[preReleaseVersion.version]' => ENV.fetch('RELEASE_VERSION')).empty?
    accepted = build_uploads.select do |upload|
      upload.dig('attributes', 'cfBundleVersion') == ENV.fetch('BUILD_NUMBER') &&
        upload.dig('attributes', 'cfBundleShortVersionString') == ENV.fetch('RELEASE_VERSION')
    end
    if accepted.any? { |upload| upload.dig('attributes', 'state', 'state') == 'FAILED' }
      raise 'Apple rejected this upload; use a new release version.'
    end
    accepted.empty?
  end

  def retire_private
    builds.select do |build|
      build.dig('attributes', 'buildAudienceType') == 'INTERNAL_ONLY' && build.dig('attributes', 'expired') == false
    end.sort_by { |build| Time.iso8601(build.fetch('attributes').fetch('uploadedDate')) }.reverse.drop(20).each do |build|
      request('PATCH', "/v1/builds/#{build.fetch('id')}", data: {
        type: 'builds', id: build.fetch('id'), attributes: { expired: true }
      })
      puts "Expired private build #{build.fetch('id')}"
    end
  end

  def distribute(audience)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1200
    loop do
      build = builds('filter[version]' => ENV.fetch('BUILD_NUMBER'),
                     'filter[preReleaseVersion.version]' => ENV.fetch('RELEASE_VERSION')).first
      state = build&.dig('attributes', 'processingState')
      raise "Apple processing failed: #{state}" if %w[FAILED INVALID].include?(state)
      if state == 'VALID'
        expected = audience == 'private' ? 'INTERNAL_ONLY' : 'APP_STORE_ELIGIBLE'
        raise 'Unexpected build audience' unless build.dig('attributes', 'buildAudienceType') == expected
        raise 'The uploaded build has expired' if build.dig('attributes', 'expired')
        detail = request('GET', "/v1/builds/#{build.fetch('id')}/buildBetaDetail").fetch('data')
        state = detail&.dig('attributes', audience == 'private' ? 'internalBuildState' : 'externalBuildState')
        unless state.nil? || state == 'PROCESSING'
          if audience == 'private'
            raise "Build is not ready for internal testing: #{state}" unless %w[READY_FOR_BETA_TESTING IN_BETA_TESTING].include?(state)
            return retire_private
          end
          return distribute_public(build.fetch('id'), detail)
        end
      end
      raise 'Apple processing did not finish within 20 minutes' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      puts "Waiting for Apple processing (#{state || 'not visible yet'})"
      sleep 30
    end
  end

  def distribute_public(id, detail)
    group = public_group
    state = detail.fetch('attributes').fetch('externalBuildState')
    case state
    when 'READY_FOR_BETA_SUBMISSION'
      locale = @app.fetch('attributes').fetch('primaryLocale')
      existing = list("/v1/builds/#{id}/betaBuildLocalizations").find { |item| item.dig('attributes', 'locale') == locale }
      notes = "MinMaxCal #{ENV.fetch('RELEASE_VERSION')}. Please test calendar and reminder permissions, agenda updates, joining events and completing reminders on iPhone and Apple Watch."
      if existing
        request('PATCH', "/v1/betaBuildLocalizations/#{existing.fetch('id')}", data: {
          type: 'betaBuildLocalizations', id: existing.fetch('id'), attributes: { whatsNew: notes }
        })
      else
        request('POST', '/v1/betaBuildLocalizations', data: {
          type: 'betaBuildLocalizations', attributes: { locale: locale, whatsNew: notes },
          relationships: { build: { data: { type: 'builds', id: id } } }
        })
      end
      request('PATCH', "/v1/buildBetaDetails/#{detail.fetch('id')}", data: {
        type: 'buildBetaDetails', id: detail.fetch('id'), attributes: { autoNotifyEnabled: true }
      })
      request('POST', '/v1/betaAppReviewSubmissions', data: {
        type: 'betaAppReviewSubmissions', relationships: { build: { data: { type: 'builds', id: id } } }
      })
    when 'READY_FOR_BETA_TESTING', 'BETA_APPROVED', 'WAITING_FOR_BETA_REVIEW', 'IN_BETA_REVIEW', 'IN_BETA_TESTING'
      # Already submitted or available; do not submit twice.
    else
      raise "Build is not ready for external testing: #{state}"
    end
    request('POST', "/v1/betaGroups/#{group}/relationships/builds", data: [{ type: 'builds', id: id }])
    if %w[READY_FOR_BETA_TESTING BETA_APPROVED].include?(state)
      request('POST', '/v1/buildBetaNotifications', data: {
        type: 'buildBetaNotifications', relationships: { build: { data: { type: 'builds', id: id } } }
      })
    end
    puts 'Build added to Public Beta; testers will be notified after any required Apple approval.'
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    case ARGV
    when ['check-release-limit']
      TestFlight.check_release_limit(TestFlight.github_pages('releases?per_page=100').flatten)
    when ['next-build-number'] then puts TestFlight.new.next_build_number
    when ['record-public'] then TestFlight.record_public
    when ['resume-public'] then puts TestFlight.resume_public
    when ['prepare-public'] then TestFlight.new.prepare_public
    when ['plan-public']
      api = TestFlight.new
      needed = api.public_upload_needed?
      api.check_public_limit if needed
      File.open(ENV.fetch('GITHUB_OUTPUT'), 'a') { |file| file.puts "needed=#{needed}" }
    when ['private'], ['public'] then TestFlight.new.distribute(ARGV.first)
    else raise 'Usage: ruby .github/testflight.rb check-release-limit|next-build-number|prepare-public|record-public|resume-public|plan-public|private|public'
    end
  rescue StandardError => error
    warn error.message
    exit 1
  end
end
