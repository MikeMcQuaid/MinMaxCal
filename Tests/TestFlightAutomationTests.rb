# Exercise TestFlight lifecycle decisions without contacting Apple or GitHub.
require 'json'
require 'time'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'open3'
require 'rbconfig'
require_relative '../.github/testflight'

def assert(condition, message)
  raise message unless condition
end

def rejects(message)
  begin
    yield
  rescue RuntimeError => error
    assert(error.message.include?(message), "Unexpected error: #{error.message}")
    return
  end
  raise "Expected rejection: #{message}"
end

class TestFlightFixture < TestFlight
  attr_reader :writes
  attr_accessor :records, :groups, :processing, :state, :details, :uploads, :fail_group_once, :artifacts

  def initialize
    @app = { 'id' => 'app', 'attributes' => { 'primaryLocale' => 'en-GB' } }
    @records = []
    @uploads = []
    @artifacts = []
    @groups = [{ 'id' => 'public', 'attributes' => { 'name' => 'Public Beta', 'isInternalGroup' => false } }]
    @writes = []
    @processing = []
    @state = 'READY_FOR_BETA_SUBMISSION'
    @details = []
  end

  def request(method, path, body = nil)
    if method != 'GET'
      @writes << [method, path, body]
      @state = 'WAITING_FOR_BETA_REVIEW' if path == '/v1/betaAppReviewSubmissions'
      if path == '/v1/betaGroups/public/relationships/builds' && @fail_group_once
        @fail_group_once = false
        raise 'Group assignment failed'
      end
      return {}
    end
    uri = URI(path)
    case uri.path
    when '/v1/builds'
      query = URI.decode_www_form(uri.query).to_h
      assert(query.fetch('filter[app]') == 'app', 'Build query must be scoped to this app')
      assert(query.fetch('filter[preReleaseVersion.platform]') == 'IOS', 'Build query must be scoped to iOS')
      if query['filter[version]']
        assert(query['filter[preReleaseVersion.version]'] == '1.2.3', 'Must match marketing version too')
        return { 'data' => @processing.shift || [] }
      end
      records = @records
      if query['filter[preReleaseVersion.version]']
        records = records.select { |build| build.dig('attributes', 'marketingVersion') == query['filter[preReleaseVersion.version]'] }
      end
      { 'data' => records }
    when '/v1/apps/app/buildUploads'
      { 'data' => @uploads }
    when '/v1/apps/app/betaGroups'
      { 'data' => @groups }
    when '/v1/builds/current/betaBuildLocalizations'
      { 'data' => [] }
    when '/v1/builds/current/buildBetaDetail'
      { 'data' => { 'id' => 'detail', 'attributes' => { 'externalBuildState' => @details.shift || @state,
                                                     'internalBuildState' => 'IN_BETA_TESTING' } } }
    else
      raise "Unexpected request: #{path}"
    end
  end

  def public_artifacts
    @artifacts
  end

  def sleep(_seconds)
    raise 'Polling did not terminate' if @processing.empty? && @details.empty?
  end
end

ENV['RELEASE_VERSION'] = '1.2.3'
ENV['BUILD_NUMBER'] = '42.2'
ENV.delete('TESTFLIGHT_PUBLIC_GROUP')
now = Time.now
release = { 'draft' => false, 'published_at' => (now - 60).iso8601 }
TestFlight.check_release_limit([release, release], now)
rejects('three releases') { TestFlight.check_release_limit([release] * 3, now) }
TestFlight.check_release_limit([release, release, { 'draft' => true, 'published_at' => now.iso8601 }], now)
TestFlight.check_release_limit([release, release, { 'published_at' => (now - 86_400).iso8601 }], now)
TestFlight.check_release_limit([{ 'published_at' => nil }], now)

def build(id, time, audience = 'INTERNAL_ONLY', **attributes)
  { 'id' => id, 'type' => 'builds', 'attributes' => {
    'uploadedDate' => time.iso8601, 'buildAudienceType' => audience,
    'processingState' => 'VALID', 'expired' => false, 'version' => '42.2'
  }.merge(attributes.transform_keys(&:to_s)) }
end

api = TestFlightFixture.new
assert(api.next_build_number == '1', 'An app without builds starts at one')
api.records = [build('old-run', now, version: '42.1'), build('newer-run', now, version: '43.1')]
assert(api.next_build_number == '44', 'Retrying run 42 must exceed run 43, irrespective of workflow run number')
api.uploads = [
  { 'attributes' => { 'platform' => 'IOS', 'cfBundleVersion' => '44.9.99' } },
  { 'attributes' => { 'platform' => 'MAC_OS', 'cfBundleVersion' => '999' } }
]
assert(api.next_build_number == '45', 'Include unfinished iOS uploads but exclude other platforms')
api.records = [build('expired', now, version: '100.2', expired: true)]
assert(api.next_build_number == '101', 'Compare numerically and never reuse expired build numbers')
api.records[0]['attributes']['version'] = 'not-a-number'
rejects('build number') { api.next_build_number }

api = TestFlightFixture.new
api.records = [build('submitted', now, 'APP_STORE_ELIGIBLE', marketingVersion: '1.2.3')]
rejects('original workflow') { api.prepare_public }
assert(api.writes.empty?, 'An existing public version without a saved upload must fail before uploading')

def artifact(name, time)
  { 'name' => name, 'created_at' => time.iso8601 }
end

def upload(number, time, state = 'PROCESSING', **attributes)
  { 'id' => "upload-#{number}", 'attributes' => {
    'cfBundleVersion' => number, 'cfBundleShortVersionString' => '1.2.3',
    'platform' => 'IOS', 'createdDate' => time.iso8601, 'uploadedDate' => nil,
    'state' => { 'state' => state }
  }.merge(attributes.transform_keys(&:to_s)) }
end

api = TestFlightFixture.new
api.artifacts = [artifact('testflight-upload-80', now)]
assert(api.next_build_number == '81', 'Unuploaded public intents reserve their build number too')
api.artifacts = (1..3).map { |n| artifact("testflight-upload-#{n}", now - 172_800) }
api.uploads = (1..3).map { |n| upload(n.to_s, now - n, 'FAILED') }
rejects('three public uploads') { api.prepare_public }
api.uploads.each { |item| item['attributes']['state']['state'] = 'PROCESSING' }
rejects('three public uploads') { api.prepare_public }
api.artifacts = []
api.prepare_public
assert(api.writes.empty?, 'Unclassified uploads must not consume public slots')
api.artifacts = (1..3).map { |n| artifact("testflight-attempt-#{n}-1", now) }
api.uploads = []
rejects('three public uploads') { api.prepare_public }
api.artifacts.each { |item| item['created_at'] = (now - 86_500).iso8601 }
rejects('three public uploads') { api.prepare_public }
api.artifacts.each { |item| item['created_at'] = (now - 90_001).iso8601 }
api.prepare_public
api.uploads = [upload('1', now - 90_001, uploadedDate: now.iso8601)]
api.artifacts += [artifact('testflight-attempt-2-1', now), artifact('testflight-attempt-3-1', now)]
rejects('three public uploads') { api.prepare_public }
api.uploads = [upload('1', now)]
api.records = [build('one', now, 'APP_STORE_ELIGIBLE', version: '1')]
api.artifacts = [artifact('testflight-upload-1', now), artifact('testflight-attempt-1-1', now)]
api.prepare_public
api.artifacts += [artifact('testflight-attempt-1-2', now), artifact('testflight-attempt-1-3', now)]
rejects('three public uploads') { api.prepare_public }
api.artifacts = [artifact('testflight-upload-1', now)]
api.uploads = [upload('1', now, platform: 'MAC_OS'), upload('2', now), upload('3', now)]
api.prepare_public

api = TestFlightFixture.new
api.artifacts = (1..2).map { |n| artifact("testflight-attempt-#{n}-1", now - 10) }
api.records = (1..2).map { |n| build(n.to_s, now, 'APP_STORE_ELIGIBLE', version: n.to_s) }
api.uploads = (1..2).map { |n| upload(n.to_s, now) }
api.prepare_public
# The first reservation is old but its accepted upload is recent; a later
# failed command using that identity is a separate attempt, not a duplicate.
api.artifacts = [artifact('testflight-attempt-1-1', now - 90_000),
                 artifact('testflight-attempt-1-2', now), artifact('testflight-attempt-2-1', now)]
api.records = []
api.uploads = [upload('1', now - 86_401, uploadedDate: (now - 86_399).iso8601)]
rejects('three public uploads') { api.prepare_public }

api = TestFlightFixture.new
assert(api.public_upload_needed?, 'An identity missing from both Apple endpoints can upload')
api.processing = [[build('current', now, 'APP_STORE_ELIGIBLE', processingState: 'PROCESSING')]]
assert(!api.public_upload_needed?, 'An accepted build must never be uploaded again')
api.uploads = [upload('42.2', now)]
assert(!api.public_upload_needed?, 'An accepted upload without a build must resume processing')
api.uploads[0]['attributes']['state']['state'] = 'FAILED'
rejects('new release version') { api.public_upload_needed? }
api.uploads[0]['attributes']['cfBundleShortVersionString'] = '1.2.4'
assert(api.public_upload_needed?, 'Reconciliation must match the release version too')
api.uploads[0]['attributes']['cfBundleShortVersionString'] = '1.2.3'
api.uploads[0]['attributes']['platform'] = 'MAC_OS'
assert(api.public_upload_needed?, 'Reconciliation must ignore other platforms')

FileUtils.mkdir_p('.test-scratch')
Dir.mktmpdir('testflight-retry.', '.test-scratch') do |scratch|
  Dir.chdir(scratch) do
    ENV['GITHUB_SHA'] = 'original-commit'
    ENV['GITHUB_RUN_ID'] = '42'
    TestFlight.record_public
    assert(TestFlight.resume_public == '42.2', 'Restore the uploaded build number for this run')
    ENV['GITHUB_SHA'] = 'another-commit'
    rejects('does not match') { TestFlight.resume_public }
    ENV['GITHUB_SHA'] = 'original-commit'
    ENV['RELEASE_VERSION'] = '1.2.4'
    rejects('does not match') { TestFlight.resume_public }
    ENV['RELEASE_VERSION'] = '1.2.3'
    ENV['GITHUB_RUN_ID'] = '43'
    rejects('does not match') { TestFlight.resume_public }
    ENV['GITHUB_RUN_ID'] = '42'

    api = TestFlightFixture.new
    api.fail_group_once = true
    api.processing = [[build('current', now, 'APP_STORE_ELIGIBLE')]] * 2
    rejects('Group assignment failed') { api.distribute('public') }
    previous_writes = api.writes.length
    ENV['BUILD_NUMBER'] = TestFlight.resume_public
    api.distribute('public')
    assert(api.writes.count { |w| w[1] == '/v1/betaAppReviewSubmissions' } == 1, 'A retry must reuse the accepted review submission')
    assert(api.writes.drop(previous_writes).map { |w| w[1] } == ['/v1/betaGroups/public/relationships/builds'],
           'Resume group assignment without rewriting a build already in review')
  end
end

api = TestFlightFixture.new
api.records = (1..22).map { |n| build("private-#{n}", now - n * 60) }.reverse
api.records += [build('public-old', now - 9999, 'APP_STORE_ELIGIBLE'),
                build('unknown', now - 9999, nil),
                build('already-expired', now, expired: true)]
api.retire_private
assert(api.writes.map { |w| w[1] }.sort == ['/v1/builds/private-21', '/v1/builds/private-22'],
       'Retire only private builds beyond the newest 20, across all versions')
assert(api.writes.all? { |w| w[0] == 'PATCH' && w[2].dig(:data, :attributes, :expired) == true },
       'Old builds must be expired')
api = TestFlightFixture.new
api.records = (1..20).map { |n| build(n.to_s, now - n) }
api.retire_private
assert(api.writes.empty?, 'Exactly 20 builds must be retained')
api.prepare_public
api.records += (1..3).map { |n| build("public-#{n}", now - n, 'APP_STORE_ELIGIBLE', expired: true) }
rejects('three public uploads') { api.prepare_public }
assert(api.writes.empty?, 'Preflight must not mutate Apple state')
api.groups[0]['attributes']['isInternalGroup'] = true
rejects('external group') { api.prepare_public }

api = TestFlightFixture.new
api.processing = [[], [build('current', now, processingState: 'PROCESSING')], [build('current', now)]]
api.distribute('private')
assert(api.writes.empty?, 'Private builds must never be submitted or assigned to external groups')
api.processing = [[build('current', now, processingState: 'INVALID')]]
rejects('INVALID') { api.distribute('private') }
api.processing = [[build('current', now, 'APP_STORE_ELIGIBLE')]]
rejects('audience') { api.distribute('private') }

api = TestFlightFixture.new
api.processing = [[build('current', now, 'APP_STORE_ELIGIBLE')]]
api.distribute('public')
assert(api.writes.any? { |w| w[1] == '/v1/betaGroups/public/relationships/builds' && w[2][:data] == [{ type: 'builds', id: 'current' }] },
       'Release build must be added to the external group')
assert(api.writes.any? { |w| w[1] == '/v1/buildBetaDetails/detail' && w[2].dig(:data, :attributes, :autoNotifyEnabled) == true },
       'Future testers must be notified automatically')
assert(api.writes.any? { |w| w[1] == '/v1/betaBuildLocalizations' && w[2].dig(:data, :attributes, :locale) == 'en-GB' },
       'Supply What to Test in the app locale')
assert(api.writes.count { |w| w[1] == '/v1/betaAppReviewSubmissions' } == 1, 'Submit exactly once for review')
assert(api.writes.index { |w| w[1] == '/v1/betaAppReviewSubmissions' } <
       api.writes.index { |w| w[1] == '/v1/betaGroups/public/relationships/builds' },
       'Submit the build before assigning it to external testers')
%w[WAITING_FOR_BETA_REVIEW IN_BETA_REVIEW IN_BETA_TESTING READY_FOR_BETA_TESTING BETA_APPROVED].each do |state|
  api = TestFlightFixture.new
  api.state = state
  api.processing = [[build('current', now, 'APP_STORE_ELIGIBLE')]]
  api.distribute('public')
  assert(api.writes.none? { |w| w[1] == '/v1/betaAppReviewSubmissions' }, 'Do not resubmit reviewed builds')
  if %w[READY_FOR_BETA_TESTING BETA_APPROVED].include?(state)
    assert(api.writes.index { |w| w[1] == '/v1/betaGroups/public/relationships/builds' } <
           api.writes.index { |w| w[1] == '/v1/buildBetaNotifications' },
           'Notify testers of an approved build after adding their group')
  end
end
api = TestFlightFixture.new
api.state = 'BETA_REJECTED'
api.processing = [[build('current', now, 'APP_STORE_ELIGIBLE')]]
rejects('BETA_REJECTED') { api.distribute('public') }
api = TestFlightFixture.new
api.details = ['PROCESSING', 'READY_FOR_BETA_SUBMISSION']
api.processing = [[build('current', now, 'APP_STORE_ELIGIBLE')]] * 2
api.distribute('public')
assert(api.writes.count { |w| w[1] == '/v1/betaAppReviewSubmissions' } == 1,
       'Wait for TestFlight processing even after archive processing is VALID')
# Exercise real pagination, JWT signing and HTTP errors with a fake transport.
original_http = Net::HTTP.method(:start)
key = OpenSSL::PKey::EC.generate('prime256v1')
ENV['APP_STORE_KEY'] = key.to_pem
ENV['APP_STORE_KEY_ID'] = 'test-key'
ENV['APP_STORE_ISSUER_ID'] = 'test-issuer'
responses = [
  { 'data' => [{ 'id' => 'app', 'attributes' => { 'primaryLocale' => 'en-GB' } }] },
  { 'data' => [{ 'id' => 'first' }], 'links' => { 'next' => 'https://api.appstoreconnect.apple.com/v1/builds?cursor=next' } },
  { 'data' => [{ 'id' => 'second' }] }
]
transport = Object.new
transport.define_singleton_method(:request) do |req|
  header, payload, signature = req['Authorization'].delete_prefix('Bearer ').split('.')
  assert(JSON.parse(Base64.urlsafe_decode64(header))['alg'] == 'ES256', 'JWT must use ES256')
  claims = JSON.parse(Base64.urlsafe_decode64(payload))
  assert(claims['aud'] == 'appstoreconnect-v1' && claims['iss'] == 'test-issuer', 'JWT audience and issuer')
  assert(claims['exp'] - claims['iat'] == 600, 'JWT should expire after ten minutes')
  raw = Base64.urlsafe_decode64(signature)
  assert(raw.bytesize == 64, 'JWT signature must contain fixed-width r and s')
  der = OpenSSL::ASN1::Sequence.new([raw[0, 32], raw[32, 32]].map do |part|
    OpenSSL::ASN1::Integer.new(OpenSSL::BN.new(part.unpack1('H*'), 16))
  end).to_der
  assert(key.verify('SHA256', der, "#{header}.#{payload}"), 'JWT signature does not verify')
  response = if responses.empty?
               Net::HTTPForbidden.new('1.1', '403', 'Forbidden')
             else
               Net::HTTPOK.new('1.1', '200', 'OK')
             end
  response.body = JSON.generate(responses.shift || { 'errors' => [{ 'detail' => 'Denied' }] })
  response.instance_variable_set(:@read, true)
  response
end
Net::HTTP.define_singleton_method(:start) { |*_args, &block| block.call(transport) }
begin
  api = TestFlight.new
  assert(api.list('/v1/builds').map { |b| b['id'] } == %w[first second], 'Read every page')
  rejects('HTTP 403') { api.retire_private }
  rejects('pagination URL') { api.request('GET', 'https://example.org/steal-token') }
ensure
  Net::HTTP.define_singleton_method(:start, original_http)
end

original_clock = Process.method(:clock_gettime)
clock = 0
Process.define_singleton_method(:clock_gettime) { |_clock| clock += 1201 }
begin
  rejects('20 minutes') { TestFlightFixture.new.distribute('private') }
ensure
  Process.define_singleton_method(:clock_gettime, original_clock)
end
# Execute the workflow's shell steps with fake Apple uploads and a saved intent.
workflow = YAML.load_file('.github/workflows/release.yml')
steps = workflow.fetch('jobs').fetch('testflight').fetch('steps')
helper = File.expand_path('../.github/testflight.rb', __dir__)
Dir.mktmpdir('testflight-workflow.', '.test-scratch') do |scratch|
  Dir.chdir(scratch) do
    FileUtils.mkdir_p(%w[bin script .build])
    File.write('.build/Version.xcconfig', "MARKETING_VERSION = 1.2.3\n")
    File.write('script/version', <<~'SH')
      #!/bin/bash
      echo 'MARKETING_VERSION = 1.2.3' >.build/version.xcconfig
    SH
    File.write('script/testflight', <<~'SH')
      #!/bin/bash
      printf '%s %s\n' "${BUILD_NUMBER}" "$*" >>uploads
      if [[ "$*" == '' ]]; then
        [[ -f saved-intent ]] || exit 99
        [[ "${APPLE_ACCEPTS:-1}" == 0 ]] || touch accepted
      fi
      exit "${UPLOAD_STATUS:-0}"
    SH
    File.write('bin/ruby', <<~'SH')
      #!/bin/bash
      case "$2" in
        next-build-number) echo "${NEXT_NUMBER}" ;;
        prepare-public) exit "${PREPARE_STATUS:-0}" ;;
        plan-public)
          [[ "${PLAN_STATUS:-0}" == 0 ]] || exit 1
          if [[ -f accepted ]]; then echo 'needed=false'; else echo 'needed=true'; fi >>"${GITHUB_OUTPUT}"
          ;;
        record-public|resume-public) exec "${TEST_RUBY}" "${TEST_HELPER}" "$2" ;;
        *) exit 99 ;;
      esac
    SH
    FileUtils.chmod(0755, %w[script/version script/testflight bin/ruby])
    env = {
      'PATH' => "#{Dir.pwd}/bin:#{ENV.fetch('PATH')}",
      'TEST_RUBY' => RbConfig.ruby, 'TEST_HELPER' => helper,
      'GITHUB_SHA' => 'original-commit', 'GITHUB_RUN_ID' => '42',
      'GITHUB_RUN_NUMBER' => '42', 'GITHUB_RUN_ATTEMPT' => '2',
      'GITHUB_EVENT_NAME' => 'workflow_run', 'GITHUB_OUTPUT' => File.expand_path('outputs'),
      'RELEASE_VERSION' => '1.2.3', 'BUILD_NUMBER' => '42.2', 'NEXT_NUMBER' => '44',
      'UPLOAD_NEEDED' => ''
    }
    execute = lambda do |id|
      File.write('outputs', '')
      step = steps.find { |item| item['id'] == id }.fetch('run')
      _out, err, status = Open3.capture3(env, 'bash', '-euo', 'pipefail', '-c', step)
      outputs = File.readlines('outputs', chomp: true).map { |line| line.split('=', 2) }.to_h
      [status.success?, outputs, err]
    end
    success, outputs, err = execute.call('prepare')
    assert(success, err)
    assert(outputs.fetch('build_number') == '44', 'Private retry must use a freshly allocated number')
    env['BUILD_NUMBER'] = outputs.fetch('build_number')
    assert(execute.call('upload')[0], 'Private upload failed')
    assert(File.read('uploads') == "44 --internal\n", 'Private upload must use the allocated number')
    assert(!File.exist?(TestFlight::UPLOAD_RECORD), 'Private uploads must not create public intents')

    env['GITHUB_EVENT_NAME'] = 'push'
    success, outputs, err = execute.call('prepare')
    assert(success && outputs.fetch('build_number') == '1', err)
    env['BUILD_NUMBER'] = outputs.fetch('build_number')
    assert(execute.call('upload')[0], 'Dry run failed')
    assert(File.read('uploads').end_with?("1 --dry-run\n"), 'Dry runs must validate without uploading')
    assert(!File.exist?(TestFlight::UPLOAD_RECORD), 'Dry runs must not create public intents')

    env['GITHUB_EVENT_NAME'] = 'workflow_dispatch'
    success, outputs, err = execute.call('prepare')
    assert(success, err)
    env['BUILD_NUMBER'] = outputs.fetch('build_number')
    assert(outputs.fetch('fresh') == 'true', 'Save a new intent before uploading')
    receipt = File.read(TestFlight::UPLOAD_RECORD)
    assert(!File.exist?('accepted'), 'Preparation must not upload to Apple')
    File.write('saved-intent', receipt)
    success, outputs, err = execute.call('plan')
    assert(success && outputs.fetch('needed') == 'true', err)
    env['UPLOAD_NEEDED'] = outputs.fetch('needed')
    env['UPLOAD_STATUS'] = '1'
    assert(!execute.call('upload')[0], 'Simulate failure after Apple accepted the upload')
    uploaded = File.read('uploads')
    assert(File.read('saved-intent') == receipt, 'Failed uploads must already have a durable recovery identity')

    # A clean retry restores the pre-upload artefact and reconciles acceptance.
    FileUtils.rm_rf('.test-scratch')
    FileUtils.mkdir_p('.test-scratch')
    FileUtils.cp('saved-intent', TestFlight::UPLOAD_RECORD)
    env['NEXT_NUMBER'] = '46'
    success, outputs, err = execute.call('prepare')
    assert(success && outputs.fetch('build_number') == '44', err)
    assert(!outputs.key?('fresh'), 'A retry must preserve the original intent')
    success, outputs, err = execute.call('plan')
    assert(success && outputs.fetch('needed') == 'false', err)
    env['UPLOAD_NEEDED'] = outputs.fetch('needed')
    assert(execute.call('upload')[0], 'An accepted upload must skip the failing upload command')
    assert(File.read('uploads') == uploaded, 'Public retry must not upload another build')
    assert(File.read(TestFlight::UPLOAD_RECORD) == receipt, 'Preserve the identity across clean retries')

    env['GITHUB_SHA'] = 'another-commit'
    assert(!execute.call('prepare')[0], 'Mismatched recovery must fail')
    assert(File.read('uploads') == uploaded, 'Mismatched recovery must not upload')
    env['GITHUB_SHA'] = 'original-commit'
    FileUtils.rm_f('accepted')
    success, outputs, err = execute.call('plan')
    assert(success && outputs.fetch('needed') == 'true', 'Retry an intent only when both Apple endpoints are empty')
    env['PLAN_STATUS'] = '1'
    assert(!execute.call('plan')[0], 'Reconciliation API errors must fail closed')
    FileUtils.rm_f(TestFlight::UPLOAD_RECORD)
    env['PREPARE_STATUS'] = '1'
    assert(!execute.call('prepare')[0], 'Failed preflight must stop preparation')
    assert(!File.exist?(TestFlight::UPLOAD_RECORD), 'Do not create an intent when preparation fails')
  end
end
# The real GitHub reader must inspect every page and ignore other workflows' identities.
Dir.mktmpdir('testflight-history.', '.test-scratch') do |scratch|
  FileUtils.mkdir_p("#{scratch}/bin")
  File.write("#{scratch}/bin/gh", <<~'SH')
    #!/bin/bash
    printf '%s\n' "$*" >"${HISTORY_ARGUMENTS}"
    [[ "${HISTORY_STATUS:-0}" == 0 ]] || exit 1
    cat "${HISTORY_FILE}"
  SH
  FileUtils.chmod(0755, "#{scratch}/bin/gh")
  run = { 'head_branch' => 'main', 'repository_id' => 1, 'head_repository_id' => 1 }
  intent = artifact('testflight-upload-50', now).merge('workflow_run' => run)
  attempt = artifact('testflight-attempt-50-1', now).merge('workflow_run' => run)
  other_branch = intent.merge('workflow_run' => run.merge('head_branch' => 'feature'))
  fork = intent.merge('workflow_run' => run.merge('head_repository_id' => 2))
  unrelated = intent.merge('name' => 'Mac app')
  File.write("#{scratch}/history.json", JSON.generate([
    { 'artifacts' => [intent, other_branch, unrelated] }, { 'artifacts' => [fork, attempt] }
  ]))
  env = { 'PATH' => "#{File.expand_path(scratch)}/bin:#{ENV.fetch('PATH')}",
          'GITHUB_REPOSITORY' => 'test/repo', 'HISTORY_FILE' => File.expand_path("#{scratch}/history.json"),
          'HISTORY_ARGUMENTS' => File.expand_path("#{scratch}/arguments") }
  command = [RbConfig.ruby, '-r', helper, '-e', 'puts JSON.generate(TestFlight.allocate.public_artifacts)']
  out, err, status = Open3.capture3(env, *command)
  assert(status.success?, err)
  assert(JSON.parse(out) == [intent, attempt], 'Read all pages and trust only same-repository main upload records')
  assert(File.read("#{scratch}/arguments").strip == 'api --paginate --slurp repos/test/repo/actions/artifacts?per_page=100',
         'Read quota records across workflow runs, with pagination')
  _out, err, status = Open3.capture3(env.merge('HISTORY_STATUS' => '1'), *command)
  assert(!status.success? && err.include?('Could not read GitHub'), 'History API errors must fail closed')
end
puts 'TestFlight automation tests passed'
