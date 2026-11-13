# Manage TestFlight distribution without third-party dependencies.
require 'base64'
require 'fileutils'
require 'json'
require 'net/http'
require 'openssl'
require 'time'
require 'timeout'
require 'tmpdir'

class TestFlight
  UPLOAD_RECORD = '.test-scratch/testflight-upload.json'
  PUBLIC_ARTIFACT = /\Atestflight-(upload|attempt)-([0-9]+(?:\.[0-9]+){0,2})(?:-v([0-9]+\.[0-9]+\.[0-9]+))?(?:-[0-9]+)?\z/

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
      next false unless artifact.fetch('name').match?(PUBLIC_ARTIFACT)
      run = artifact['workflow_run']
      next false unless run
      run.fetch('head_branch') == 'main' && run.fetch('head_repository_id') == run.fetch('repository_id')
    end
  end

  def build_uploads(deadline = nil)
    @included_upload_builds = {}
    list("/v1/apps/#{@app.fetch('id')}/buildUploads", { 'include' => 'build' }, deadline) do |page|
      page.fetch('included', []).each do |build|
        @included_upload_builds[build.fetch('id')] = build if build['type'] == 'builds'
      end
    end.select { |upload| upload.dig('attributes', 'platform') == 'IOS' }
  end

  def initialize
    @key = OpenSSL::PKey.read(ENV.fetch('APP_STORE_KEY'))
    apps = list('/v1/apps', 'filter[bundleId]' => 'com.mikemcquaid.MinMaxCal')
    raise 'Expected one MinMaxCal App Store Connect record' unless apps.length == 1
    @app = apps.first
  end

  def request(method, path, body = nil, deadline = nil)
    processing_time_left(deadline) if deadline
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
    response = Timeout.timeout(deadline && processing_time_left(deadline), RuntimeError,
                               'Apple processing did not finish within 20 minutes') do
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 30, read_timeout: 60) do |http|
        http.request(req)
      end
    end
    processing_time_left(deadline) if deadline
    unless response.is_a?(Net::HTTPSuccess)
      raise "App Store Connect #{method} #{uri.path}: HTTP #{response.code}: #{response.body}"
    end
    response.body.to_s.empty? ? {} : JSON.parse(response.body)
  end

  def list(path, query = {}, deadline = nil)
    path = "#{path}?#{URI.encode_www_form(query.merge('limit' => 200))}"
    records = []
    while path
      processing_time_left(deadline) if deadline
      page = request('GET', path, nil, deadline)
      processing_time_left(deadline) if deadline
      records.concat(page.fetch('data'))
      yield page if block_given?
      path = page.dig('links', 'next')
    end
    records
  end

  def builds(query = {}, deadline = nil)
    list('/v1/builds', {
      'filter[app]' => @app.fetch('id'), 'filter[preReleaseVersion.platform]' => 'IOS',
      'sort' => '-uploadedDate', 'include' => 'preReleaseVersion,buildUpload'
    }.merge(query), deadline) do |page|
      @versions ||= {}
      page.fetch('included', []).each do |record|
        @versions[record.fetch('id')] = record.dig('attributes', 'version') if record['type'] == 'preReleaseVersions'
      end
    end
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

  def artifact_identity(artifact)
    match = PUBLIC_ARTIFACT.match(artifact.fetch('name'))
    return [match[3], match[2]] if match[3]
    # Older workflow runs saved the version only inside their intent.
    @intents ||= {}
    @intents[artifact.fetch('name')] ||= begin
      FileUtils.mkdir_p('.test-scratch')
      Dir.mktmpdir('testflight-intent.', '.test-scratch') do |directory|
        run = artifact.fetch('workflow_run').fetch('id').to_s
        unless system('gh', 'run', 'download', run, '--repo', ENV.fetch('GITHUB_REPOSITORY'),
                      '--name', artifact.fetch('name'), '--dir', directory)
          raise 'Could not read the saved public upload identity'
        end
        record = JSON.parse(File.read(File.join(directory, 'testflight-upload.json')))
        unless record.fetch('GITHUB_RUN_ID') == run && record.fetch('BUILD_NUMBER') == match[2]
          raise 'The saved public upload identity does not match its artefact'
        end
        [record.fetch('RELEASE_VERSION'), record.fetch('BUILD_NUMBER')]
      end
    end
  end

  def build_identity(build)
    [@versions.fetch(build.dig('relationships', 'preReleaseVersion', 'data', 'id')),
     build.fetch('attributes').fetch('version')]
  end

  def upload_identity(upload)
    [upload.fetch('attributes').fetch('cfBundleShortVersionString'), upload.fetch('attributes').fetch('cfBundleVersion')]
  end

  def public_uploads(records, artifacts, now = Time.now)
    public_identities = records.select { |build| build.dig('attributes', 'buildAudienceType') == 'APP_STORE_ELIGIBLE' }
                               .map { |build| build_identity(build) }
    private_identities = records.select { |build| build.dig('attributes', 'buildAudienceType') == 'INTERNAL_ONLY' }
                                .map { |build| build_identity(build) }
    build_uploads.select do |upload|
      linked = @included_upload_builds[upload.dig('relationships', 'build', 'data', 'id')] || records.find do |build|
        build['id'] == upload.dig('relationships', 'build', 'data', 'id') ||
          build.dig('relationships', 'buildUpload', 'data', 'id') == upload.fetch('id')
      end
      if %w[APP_STORE_ELIGIBLE INTERNAL_ONLY].include?(linked&.dig('attributes', 'buildAudienceType'))
        linked.dig('attributes', 'buildAudienceType') == 'APP_STORE_ELIGIBLE'
      else
        identity = upload_identity(upload)
        next false if private_identities.include?(identity)
        known_public = public_identities.include?(identity) || artifacts.any? do |artifact|
          PUBLIC_ARTIFACT.match(artifact.fetch('name'))[2] == identity[1] && artifact_identity(artifact) == identity
        end
        unless known_public
          timestamps = [upload.fetch('attributes').fetch('createdDate'), upload.dig('attributes', 'uploadedDate')].compact
          if timestamps.any? { |timestamp| Time.iso8601(timestamp) > now - 86_400 }
            raise "Cannot determine the audience of upload #{identity.join(' / ')}; wait for Apple to identify its build audience or for its timestamps to leave the 24-hour window."
          end
        end
        known_public
      end
    end
  end

  def prepare_public
    public_group
    check_public_version
    check_public_limit
  end

  def check_public_version(accepted_number = nil)
    records = builds
    if records.any? { |build| build.dig('attributes', 'buildAudienceType') == 'APP_STORE_ELIGIBLE' &&
                             build_identity(build)[0] == ENV.fetch('RELEASE_VERSION') &&
                             build_identity(build)[1] != accepted_number } ||
       public_uploads(records, public_artifacts).any? do |upload|
         upload_identity(upload)[0] == ENV.fetch('RELEASE_VERSION') && upload_identity(upload)[1] != accepted_number
       end
      raise 'A public build or upload already exists for this version; retry its original workflow or use a new version.'
    end
  end

  def check_public_limit(now = Time.now)
    cutoff = now - 86_400
    records = builds
    artifacts = public_artifacts
    accepted = public_uploads(records, artifacts, now)
    attempts = accepted.map do |upload|
      attributes = upload.fetch('attributes')
      { identity: upload_identity(upload), created: Time.iso8601(attributes.fetch('createdDate')),
        finished: attributes['uploadedDate'] && Time.iso8601(attributes['uploadedDate']) }
    end
    records.select { |build| build.dig('attributes', 'buildAudienceType') == 'APP_STORE_ELIGIBLE' }.each do |build|
      identity = build_identity(build)
      uploaded = Time.iso8601(build.fetch('attributes').fetch('uploadedDate'))
      match = accepted.index do |upload|
        upload.dig('relationships', 'build', 'data', 'id') == build['id'] ||
          build.dig('relationships', 'buildUpload', 'data', 'id') == upload['id']
      end
      match ||= accepted.index do |upload|
        upload_identity(upload) == identity && upload.dig('attributes', 'state', 'state') != 'FAILED'
      end
      if match
        attempts[match][:finished] = [attempts[match][:finished], uploaded].compact.max
      else
        attempts << { identity: identity, created: uploaded, processed: true }
      end
    end
    count = attempts.count { |attempt| attempt[:created] > cutoff || (attempt[:finished] && attempt[:finished] > cutoff) }
    # A retry's upload can only confirm the reservation for that attempt.
    artifacts.select { |artifact| artifact.fetch('name').start_with?('testflight-attempt-') }
             .sort_by { |artifact| artifact.fetch('created_at') }
             .group_by { |artifact| artifact_identity(artifact) }.each do |identity, reservations|
      reservations.each_with_index do |artifact, index|
        start = Time.iso8601(artifact.fetch('created_at'))
        next_start = reservations[index + 1]&.fetch('created_at')
        match = attempts.index do |attempt|
          attempt[:identity] == identity && attempt[:created] >= start &&
            (attempt[:processed] || attempt[:created] <= start + 3600) &&
            (!next_start || attempt[:created] < Time.iso8601(next_start))
        end
        if match
          attempts.delete_at(match)
        elsif start + 3600 > cutoff
          count += 1
        end
      end
    end
    raise 'Already made or reserved three public uploads in the past 24 hours; wait before retrying.' if count >= 3
  end

  def public_upload_needed?
    return false unless builds('filter[version]' => ENV.fetch('BUILD_NUMBER'),
                               'filter[preReleaseVersion.version]' => ENV.fetch('RELEASE_VERSION')).empty?
    return false unless matching_uploads.empty?
    check_public_version(ENV.fetch('BUILD_NUMBER'))
    true
  end

  def matching_uploads(audience = 'public', deadline = nil)
    accepted = build_uploads(deadline).select do |upload|
      upload_identity(upload) == [ENV.fetch('RELEASE_VERSION'), ENV.fetch('BUILD_NUMBER')]
    end
    usable = accepted.reject { |upload| %w[FAILED AWAITING_UPLOAD].include?(upload.dig('attributes', 'state', 'state')) }
    return usable unless usable.empty?
    recovery = audience == 'private' ? 'retry the workflow after correcting the upload problem.' : 'start a new Release run with a fresh version.'
    if accepted.any? { |upload| upload.dig('attributes', 'state', 'state') == 'AWAITING_UPLOAD' }
      raise "Apple has not received the binary: AWAITING_UPLOAD; #{recovery}"
    end
    if accepted.any? { |upload| upload.dig('attributes', 'state', 'state') == 'FAILED' }
      recovery = 'use a new release version.' if audience == 'public'
      raise "Apple rejected this upload; #{recovery}"
    end
    usable
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

  def processing_time_left(deadline)
    remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
    raise 'Apple processing did not finish within 20 minutes' unless remaining.positive?
    remaining
  end

  def distribute(audience)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1200
    loop do
      processing_time_left(deadline)
      build = builds({ 'filter[version]' => ENV.fetch('BUILD_NUMBER'),
                       'filter[preReleaseVersion.version]' => ENV.fetch('RELEASE_VERSION') }, deadline).first
      processing_time_left(deadline)
      matching_uploads(audience, deadline) unless build
      state = build&.dig('attributes', 'processingState')
      raise "Apple processing failed: #{state}" if %w[FAILED INVALID].include?(state)
      if state == 'VALID'
        expected = audience == 'private' ? 'INTERNAL_ONLY' : 'APP_STORE_ELIGIBLE'
        raise 'Unexpected build audience' unless build.dig('attributes', 'buildAudienceType') == expected
        raise 'The uploaded build has expired' if build.dig('attributes', 'expired')
        detail = request('GET', "/v1/builds/#{build.fetch('id')}/buildBetaDetail", nil, deadline).fetch('data')
        processing_time_left(deadline)
        state = detail&.dig('attributes', audience == 'private' ? 'internalBuildState' : 'externalBuildState')
        unless state.nil? || state == 'PROCESSING'
          if audience == 'private'
            raise "Build is not ready for internal testing: #{state}" unless %w[READY_FOR_BETA_TESTING IN_BETA_TESTING].include?(state)
            return retire_private
          end
          return distribute_public(build.fetch('id'), detail)
        end
      end
      puts "Waiting for Apple processing (#{state || 'not visible yet'})"
      sleep [30, processing_time_left(deadline)].min
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
    puts 'Build added to the configured external group; testers will be notified after any required Apple approval.'
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
