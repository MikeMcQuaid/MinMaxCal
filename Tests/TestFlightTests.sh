#!/bin/bash
# Check release gating, signing cleanup and uploads without credentials.
set -euo pipefail

cd "$(dirname "$0")/.."
ruby -ryaml <<'WORKFLOW'
workflow = YAML.load_file('.github/workflows/release.yml')
jobs = workflow.fetch('jobs')
def enabled?(job, values)
  expression = job.fetch('if').gsub(/\s+/, ' ')
  values.each { |key, value| expression = expression.gsub(key, value.inspect) }
  eval(expression)
end
release = jobs.fetch('release')
unless Array(release['needs']).include?('testflight')
  abort 'GitHub publication can run before TestFlight succeeds'
end
results = %w[success skipped failure cancelled]
%w[workflow_dispatch push workflow_run].product(results, results, results, [false, true]).each do |event, build, smoke, upload, cancelled|
  values = { 'github.event_name' => event, 'cancelled()' => cancelled, 'needs.build.result' => build,
             'needs.smoke-test.result' => smoke, 'needs.testflight.result' => upload }
  expected = !cancelled && event == 'workflow_dispatch' && [build, smoke, upload].all? { |result| result == 'success' }
  abort 'GitHub publication must require successful release jobs' unless enabled?(release, values) == expected
end
testflight = jobs.fetch('testflight')
matrix = testflight.dig('strategy', 'matrix', 'include')
unless matrix&.map { |item| item['platform'] } == %w[IOS MAC_OS] &&
       testflight.dig('strategy', 'max-parallel') == 1 && testflight.dig('strategy', 'fail-fast') == false
  abort 'Upload both platforms serially without cancelling the other platform on failure'
end
unless matrix.map { |item| item['artifact_prefix'] } == %w[testflight testflight-macos] &&
       testflight.dig('env', 'TESTFLIGHT_PLATFORM') == '${{ matrix.platform }}'
  abort 'Platform uploads must have distinct recovery artefacts and API scopes'
end
if Array(testflight['needs']).include?('release') || testflight.fetch('if', '').include?('needs.release')
  abort 'TestFlight depends on GitHub publication'
end
if testflight['continue-on-error'] || testflight.fetch('steps').any? { |step| step['continue-on-error'] }
  abort 'TestFlight failures can be ignored'
end
trigger = workflow.fetch(true).fetch('workflow_run')
unless trigger.fetch('types') == ['completed'] && trigger.fetch('branches') == ['main'] &&
       trigger.fetch('workflows') == ['GitHub Actions CI']
  abort 'Only completed main CI may trigger private publishing'
end
ci = YAML.load_file('.github/workflows/tests.yml').dig('jobs', 'testflight-changes')
unless ci.fetch('if') == "github.event_name == 'push'" &&
       ci.fetch('concurrency') == { 'group' => 'private-testflight-${{ github.event.before }}', 'cancel-in-progress' => true } &&
       ci.fetch('steps').last.fetch('if') == "steps.swift.outputs.changed == 'true'"
  abort 'Each push must supersede the previous tip and record eligible changes'
end
unless workflow.dig('concurrency', 'queue') == 'max' && testflight.dig('concurrency', 'queue') == 'max'
  abort 'Live uploads and official releases must queue'
end
groups = workflow.dig('concurrency', 'group').delete_prefix('${{').delete_suffix('}}').gsub(/\s+/, ' ').gsub('{0}', '%s')
upload_group = testflight.dig('concurrency', 'group').delete_prefix('${{').delete_suffix('}}')
{ 'workflow_run' => ['private-testflight-tested', 'minmaxcal-release'], 'workflow_dispatch' => ['minmaxcal-release', 'run'],
  'push' => ['minmaxcal-release-dry-run-refs/heads/main', 'run'] }.each do |event, expected|
  actual = [groups, upload_group].map do |expr|
    eval(expr.gsub('github.event_name', event.inspect).gsub('github.ref', "'refs/heads/main'")
             .gsub('github.event.workflow_run.head_sha', "'tested'").gsub('github.run_id', "'run'"))
  end
  abort "Unexpected release queues for #{event}: #{actual}" unless actual == expected
end
candidate = jobs.fetch('private-build')
abort 'TestFlight must wait for the Swift change check' unless testflight.fetch('needs').include?('private-build')
%w[workflow_run workflow_dispatch push].product(%w[push pull_request], %w[main feature],
  %w[local foreign], %w[success failure cancelled skipped], %w[success failure skipped],
  %w[success failure skipped], %w[maintainer dependabot[bot]], [false, true]).each do |event, cause, branch, repo, conclusion, build, smoke, actor, cancelled|
  values = {
    'github.event_name' => event, 'github.event.workflow_run.event' => cause,
    'github.event.workflow_run.head_branch' => branch,
    'github.event.workflow_run.head_repository.full_name' => repo, 'github.repository' => 'local',
    'github.event.workflow_run.conclusion' => conclusion, 'github.actor' => actor,
    'needs.build.result' => build, 'needs.smoke-test.result' => smoke, 'cancelled()' => cancelled
  }
  trusted = event == 'workflow_run' && cause == 'push' && branch == 'main' && repo == 'local' && conclusion == 'success'
  abort "Unsafe private candidate: #{values}" unless enabled?(candidate, values) == trusted
  %w[true false].each do |changed|
    values['needs.private-build.outputs.eligible'] = trusted ? changed : ''
    expected = !cancelled && (trusted && changed == 'true' ||
      event != 'workflow_run' && actor != 'dependabot[bot]' && build == 'success' && smoke == 'success')
    abort "Unsafe TestFlight trigger: #{values}" unless enabled?(testflight, values) == expected
  end
end
build_steps = jobs.fetch('build').fetch('steps')
quota = build_steps.index { |step| step.fetch('run', '').include?('check-release-limit') }
build = build_steps.index { |step| step.fetch('run', '') == 'script/build' }
unless quota && build && quota < build && build_steps[quota]['if'] == "github.event_name == 'workflow_dispatch'"
  abort 'Release limit is not checked before building'
end
archive = build_steps.find { |step| step.dig('with', 'name') == 'MinMaxCal' }
unless archive.dig('with', 'retention-days') == "${{ github.event_name == 'workflow_dispatch' && 30 || 1 }}"
  abort 'Manual release ZIPs must survive the 30-day rerun window'
end
publish = release.fetch('steps').last.fetch('run')
unless publish.index('check-release-limit') && publish.index('check-release-limit') < publish.index('git push')
  abort 'Release limit is not checked before pushing the tag'
end
steps = testflight.fetch('steps')
upload = steps.find { |step| step['id'] == 'upload' }
abort 'Upload step needs outputs for distribution recovery' unless upload
unless steps.last.fetch('if').include?("steps.upload.outputs.superseded != 'true'")
  abort 'A superseded private upload must skip Apple processing'
end
%w[IOS MAC_OS].product([false, 'mac-bundle'], [false, 'mac-password']).each do |platform, bundle, password|
  values = {
    'matrix.platform' => platform, 'secrets.MINMAXCAL_APP_STORE_MACOS_CERTIFICATES' => bundle,
    'secrets.MINMAXCAL_APP_STORE_MACOS_CERTIFICATES_PASSWORD' => password,
    'secrets.APP_STORE_CERTIFICATES' => 'shared-bundle', 'secrets.APP_STORE_CERTIFICATES_PASSWORD' => 'shared-password'
  }
  expected = platform == 'MAC_OS' && bundle ? [bundle, password] : ['shared-bundle', 'shared-password']
  actual = %w[APP_STORE_CERTIFICATES APP_STORE_CERTIFICATES_PASSWORD].map do |key|
    expression = upload.fetch('env').fetch(key).delete_prefix('${{').delete_suffix('}}')
    expression = expression.gsub(/matrix\.platform|secrets\.[A-Z_]+/) { |name| values.fetch(name).inspect }
    eval(expression)
  end
  abort 'Mac certificate overrides must use their own password without changing iOS signing' unless actual == expected
end
prepare = steps.find { |step| step['id'] == 'prepare' }
abort 'Allocate an upload identity before archiving' unless prepare
restore = steps.index { |step| step.dig('with', 'pattern') == '${{ matrix.artifact_prefix }}-upload*' }
record = steps.index { |step| step.dig('with', 'name').to_s.start_with?('${{ matrix.artifact_prefix }}-upload-') }
reservation = steps.index { |step| step.dig('with', 'name').to_s.start_with?('${{ matrix.artifact_prefix }}-attempt-') }
unless restore && record && reservation && restore < steps.index(prepare) && steps.index(prepare) < record && record < reservation && reservation < steps.index(upload)
  abort 'Save the identity and quota reservation before uploading to Apple'
end
[record, reservation].each do |index|
  unless steps[index].dig('with', 'name').include?('-v${{ steps.prepare.outputs.release_version }}')
    abort 'Public artefacts must identify the marketing version as well as the build number'
  end
end
unless steps[record]['if'].include?("steps.prepare.outputs.fresh == 'true'")
  abort 'A retry must preserve the saved upload intent'
end
abort 'Quota history needs Actions read permission' unless testflight.dig('permissions', 'actions') == 'read'
abort 'Build numbers still depend on workflow run order' if prepare.fetch('run').include?('run_number')
puts 'TestFlight release gating tests passed'
WORKFLOW
mkdir -p "${PWD}/.test-scratch"
scratch="$(mktemp -d "${PWD}/.test-scratch/testflight.XXXXXX")"
trap 'rm -rf "${scratch}"' EXIT
mkdir -p "${scratch}/bin"
export TESTFLIGHT_TEST_DIRECTORY="${scratch}"
export PATH="${scratch}/bin:${PATH}"

cat >"${scratch}/bin/security" <<'SECURITY'
#!/bin/bash
set -euo pipefail
echo "$1" >>"${TESTFLIGHT_TEST_DIRECTORY}/security.log"
case "$1" in
  list-keychains)
    if [[ $# == 3 ]]; then
      cat "${TESTFLIGHT_TEST_DIRECTORY}/keychains"
      [[ "${TESTFLIGHT_TEST_FAILURE}" != list ]] || exit 1
    else
      shift 4
      printf '%s\n' "$@" >"${TESTFLIGHT_TEST_DIRECTORY}/keychains"
    fi
    ;;
  create-keychain)
    echo /created-concurrently.keychain-db >>"${TESTFLIGHT_TEST_DIRECTORY}/keychains"
    dirname "$4" >"${TESTFLIGHT_TEST_DIRECTORY}/credentials"
    [[ "${TESTFLIGHT_TEST_FAILURE}" != create ]]
    ;;
  delete-keychain)
    awk -v removed="$2" '$0 != removed' "${TESTFLIGHT_TEST_DIRECTORY}/keychains" >"${TESTFLIGHT_TEST_DIRECTORY}/remaining"
    mv "${TESTFLIGHT_TEST_DIRECTORY}/remaining" "${TESTFLIGHT_TEST_DIRECTORY}/keychains"
    ;;
  cms)
    echo /concurrent.keychain-db >"${TESTFLIGHT_TEST_DIRECTORY}/keychains"
    cat "$4"
    ;;
  import) [[ "${TESTFLIGHT_TEST_FAILURE}" != import ]] ;;
  find-identity)
    [[ $# == 5 && "$2" == -v && "$3" == -p && "$4" == basic ]]
    [[ "$5" == "$(cat "${TESTFLIGHT_TEST_DIRECTORY}/credentials")/signing.keychain-db" ]]
    [[ "${TESTFLIGHT_TEST_FAILURE}" != installer ]] || exit 0
    echo '1) AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA "Apple Distribution: Test (ABCDEFGHIJ)"'
    echo '2) BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB "3rd Party Mac Developer Installer: Other (OTHERTEAM1)"'
    [[ "${TESTFLIGHT_TEST_FAILURE}" != installer-team ]] || exit 0
    echo '3) 1234567890ABCDEF1234567890ABCDEF12345678 "3rd Party Mac Developer Installer: Test (ABCDEFGHIJ)"'
    ;;
esac
SECURITY
cat >"${scratch}/bin/xcodebuild" <<'XCODEBUILD'
#!/bin/bash
set -euo pipefail
echo /archive-concurrent.keychain-db >>"${TESTFLIGHT_TEST_DIRECTORY}/keychains"
credentials="$(cat "${TESTFLIGHT_TEST_DIRECTORY}/credentials")"
[[ "$(stat -f '%Lp' "${credentials}")" == 700 ]]
for secret in certificates.p12 key.p8; do
  [[ "$(stat -f '%Lp' "${credentials}/${secret}")" == 600 ]] || {
    echo 'Signing credentials must remain private during archive and export' >&2
    exit 1
  }
done
if [[ "${TESTFLIGHT_PLATFORM}" == MAC_OS ]]; then
  app="$(mktemp -d "${TESTFLIGHT_TEST_DIRECTORY}/signature.XXXXXX")/Test.app"
  mkdir -p "${app}/Contents/MacOS"
  cp /usr/bin/true "${app}/Contents/MacOS/Test"
  /usr/libexec/PlistBuddy -c 'Add :CFBundleExecutable string Test' \
    -c 'Add :CFBundleIdentifier string com.example.PermissionTest' \
    -c 'Add :CFBundlePackageType string APPL' "${app}/Contents/Info.plist" >/dev/null
  chmod -R a+rX "${app}"
  /usr/bin/codesign --force --sign - "${app}"
  [[ "$(stat -f '%Lp' "${app}/Contents/_CodeSignature/CodeResources")" == 644 ]] || {
    echo 'Mac code signatures must be readable by all users after archive and export' >&2
    exit 1
  }
fi
if [[ "$1" == -exportArchive ]]; then
  while [[ "$1" != -exportOptionsPlist ]]; do shift; done
  cp "$2" "${TESTFLIGHT_TEST_DIRECTORY}/export.plist"
  destination="$(/usr/libexec/PlistBuddy -c 'Print :destination' "$2")"
  echo "${destination}" >>"${TESTFLIGHT_TEST_DIRECTORY}/calls"
  [[ "${TESTFLIGHT_TEST_FAILURE}" != export ]]
else
  echo archive >>"${TESTFLIGHT_TEST_DIRECTORY}/calls"
  printf '%s\n' "$@" >"${TESTFLIGHT_TEST_DIRECTORY}/archive.args"
  [[ "${TESTFLIGHT_TEST_FAILURE}" != archive ]]
fi
XCODEBUILD
cat >"${scratch}/bin/xcrun" <<'VALIDATOR'
#!/bin/bash
set -euo pipefail
[[ "$1" == altool && "$2" == --validate-app ]]
extension=ipa
[[ "${TESTFLIGHT_PLATFORM:-IOS}" == MAC_OS ]] && extension=pkg
[[ "$3" == */export/MinMaxCal."${extension}" ]]
[[ "$4" == --api-key && "$5" == KEY1234567 ]]
[[ "$6" == --api-issuer && "$7" == issuer ]]
[[ "$8" == --p8-file-path && "$(cat "$9")" == 'test API key' ]]
echo validate >>"${TESTFLIGHT_TEST_DIRECTORY}/calls"
[[ "${TESTFLIGHT_TEST_FAILURE}" != validate ]]
VALIDATOR
chmod +x "${scratch}/bin/"*

export RELEASE_VERSION=1.2.3 BUILD_NUMBER=42.2
unset APP_STORE_TEAM_ID APP_STORE_MACOS_PROFILE TESTFLIGHT_PLATFORM
export APP_STORE_KEY='test API key' APP_STORE_KEY_ID=KEY1234567 APP_STORE_ISSUER_ID=issuer
export APP_STORE_CERTIFICATES=dGVzdA== APP_STORE_CERTIFICATES_PASSWORD=password
for platform in IOS WATCHOS MACOS; do
  bundle_id=com.mikemcquaid.MinMaxCal
  [[ "${platform}" == WATCHOS ]] && bundle_id+=.watchkitapp
  identifier=application-identifier
  [[ "${platform}" == MACOS ]] && identifier=com.apple.application-identifier
  plutil -create xml1 "${scratch}/${platform}.plist"
  /usr/libexec/PlistBuddy -c "Add :UUID string $(uuidgen)" \
    -c 'Add :TeamIdentifier array' -c 'Add :TeamIdentifier:0 string ABCDEFGHIJ' \
    -c 'Add :Entitlements dict' \
    -c "Add :Entitlements:${identifier} string OLDPREFIX1.${bundle_id}" \
    "${scratch}/${platform}.plist"
  export "APP_STORE_${platform}_PROFILE=$(base64 -i "${scratch}/${platform}.plist")"
done

if script/testflight macOS >"${scratch}/platform.log" 2>&1; then
  echo 'Unexpected platform argument did not prevent an upload' >&2
  exit 1
fi
if env -u APP_STORE_WATCHOS_PROFILE script/testflight >"${scratch}/missing.log" 2>&1; then
  echo 'Missing Watch profile did not prevent an upload' >&2
  exit 1
fi
grep -q 'Missing APP_STORE_WATCHOS_PROFILE' "${scratch}/missing.log"
[[ ! -e "${scratch}/security.log" ]]

if env -u APP_STORE_MACOS_PROFILE TESTFLIGHT_PLATFORM=MAC_OS script/testflight --internal >"${scratch}/missing-mac.log" 2>&1; then
  echo 'Missing Mac profile did not prevent an upload' >&2
  exit 1
fi
grep -q 'Missing APP_STORE_MACOS_PROFILE' "${scratch}/missing-mac.log"

for platform in IOS WATCHOS MACOS; do
  export TESTFLIGHT_PLATFORM=IOS
  identifier=application-identifier
  if [[ "${platform}" == MACOS ]]; then
    export TESTFLIGHT_PLATFORM=MAC_OS
    identifier=com.apple.application-identifier
  fi
  cp "${scratch}/${platform}.plist" "${scratch}/wrong-profile.plist"
  /usr/libexec/PlistBuddy -c "Set :Entitlements:${identifier} OLDPREFIX1.com.example.OtherApp" \
    "${scratch}/wrong-profile.plist"
  if env "APP_STORE_${platform}_PROFILE=$(base64 -i "${scratch}/wrong-profile.plist")" TESTFLIGHT_TEST_FAILURE=none \
    script/testflight --dry-run >"${scratch}/wrong-profile.log" 2>&1; then
    echo "An incorrect ${platform} bundle identifier did not prevent archiving" >&2
    exit 1
  fi
  grep -q "MINMAXCAL_APP_STORE_${platform}_PROFILE" "${scratch}/wrong-profile.log"
  [[ ! -e "${scratch}/calls" ]]
  [[ "$(cat "${scratch}/keychains")" == /concurrent.keychain-db ]] || {
    echo 'Profile validation restored a stale keychain search list' >&2
    exit 1
  }
  if grep -Eq '^(create-keychain|import)$' "${scratch}/security.log"; then
    echo 'An invalid profile changed the signing keychain' >&2
    exit 1
  fi
  for profile in IOS WATCHOS MACOS; do
    uuid="$(/usr/libexec/PlistBuddy -c 'Print UUID' "${scratch}/${profile}.plist")"
    extension=mobileprovision
    [[ "${profile}" == MACOS ]] && extension=provisionprofile
    [[ ! -e "${HOME}/Library/Developer/Xcode/UserData/Provisioning Profiles/${uuid}.${extension}" ]]
  done
  rm -f "${scratch}/security.log"
done

for TESTFLIGHT_PLATFORM in IOS MAC_OS; do
  export TESTFLIGHT_PLATFORM
  profiles=(IOS WATCHOS)
  [[ "${TESTFLIGHT_PLATFORM}" == MAC_OS ]] && profiles=(MACOS)
  for audience in public private dry-run; do
    mode=upload
    args=()
    [[ "${audience}" == private ]] && args=(--internal)
    if [[ "${audience}" == dry-run ]]; then
      mode="export"
      args=(--dry-run)
    fi
    for failure in list none create import installer installer-team archive export validate; do
      [[ "${TESTFLIGHT_PLATFORM}" == IOS && "${failure}" == installer* ]] && continue
      [[ "${mode}" == upload && "${failure}" == validate ]] && continue
      export TESTFLIGHT_TEST_FAILURE="${failure}"
      rm -f "${scratch}/calls" "${scratch}/security.log"
      if script/testflight ${args[@]+"${args[@]}"} >"${scratch}/run.log" 2>&1; then
        [[ "${failure}" == none ]] || {
          echo "Signing ignored ${failure} failure" >&2
          exit 1
        }
      else
        [[ "${failure}" != none ]] || {
          cat "${scratch}/run.log"
          exit 1
        }
      fi
      [[ ! -d "$(cat "${scratch}/credentials")" ]]
      grep -qx delete-keychain "${scratch}/security.log"
      grep -qx /concurrent.keychain-db "${scratch}/keychains"
      grep -qx /created-concurrently.keychain-db "${scratch}/keychains"
      if [[ -e "${scratch}/calls" ]]; then
        grep -qx /archive-concurrent.keychain-db "${scratch}/keychains"
      fi
      if grep -q signing.keychain-db "${scratch}/keychains"; then
        echo 'Temporary keychain remained in the search list' >&2
        exit 1
      fi
      for profile in "${profiles[@]}"; do
        uuid="$(/usr/libexec/PlistBuddy -c 'Print UUID' "${scratch}/${profile}.plist")"
        extension=mobileprovision
        [[ "${profile}" == MACOS ]] && extension=provisionprofile
        [[ ! -e "${HOME}/Library/Developer/Xcode/UserData/Provisioning Profiles/${uuid}.${extension}" ]]
      done
      if [[ "${failure}" == installer* ]]; then
        grep -q 'Mac Installer Distribution.*ABCDEFGHIJ' "${scratch}/run.log"
      fi
      if [[ "${failure}" == create || "${failure}" == import || "${failure}" == list || "${failure}" == installer* ]]; then
        [[ ! -e "${scratch}/calls" ]]
        continue
      fi
      if [[ "${TESTFLIGHT_PLATFORM}" == MAC_OS ]]; then
        grep -qx MinMaxCal-AppStore "${scratch}/archive.args"
        grep -qx generic/platform=macOS "${scratch}/archive.args"
      else
        grep -qx MinMaxCal-iOS "${scratch}/archive.args"
        grep -qx generic/platform=iOS "${scratch}/archive.args"
      fi
      grep -qx DEVELOPMENT_TEAM=ABCDEFGHIJ "${scratch}/archive.args"
      grep -qx MARKETING_VERSION=1.2.3 "${scratch}/archive.args"
      grep -qx CURRENT_PROJECT_VERSION=42.2 "${scratch}/archive.args"
      if [[ "${failure}" == archive ]]; then
        [[ "$(cat "${scratch}/calls")" == archive ]]
      else
        grep -qx "${mode}" "${scratch}/calls"
        if [[ "${mode}" == export && "${failure}" != export ]]; then
          [[ "$(cat "${scratch}/calls")" == $'archive\nexport\nvalidate' ]]
        else
          [[ "$(cat "${scratch}/calls")" == "$(printf 'archive\n%s' "${mode}")" ]]
        fi
        if [[ "${TESTFLIGHT_PLATFORM}" == MAC_OS ]]; then
          [[ "$(/usr/libexec/PlistBuddy -c 'Print :installerSigningCertificate' "${scratch}/export.plist")" == 1234567890ABCDEF1234567890ABCDEF12345678 ]] || {
            echo 'Mac export must select the imported installer identity for the provisioning team' >&2
            exit 1
          }
        fi
        [[ "$(/usr/libexec/PlistBuddy -c 'Print :method' "${scratch}/export.plist")" == app-store-connect ]]
        [[ "$(/usr/libexec/PlistBuddy -c 'Print :destination' "${scratch}/export.plist")" == "${mode}" ]]
        internal=false
        [[ "${audience}" == private ]] && internal=true
        [[ "$(/usr/libexec/PlistBuddy -c 'Print :testFlightInternalTestingOnly' "${scratch}/export.plist")" == "${internal}" ]]
        [[ "$(/usr/libexec/PlistBuddy -c 'Print :teamID' "${scratch}/export.plist")" == ABCDEFGHIJ ]]
        [[ "$(/usr/libexec/PlistBuddy -c 'Print :manageAppVersionAndBuildNumber' "${scratch}/export.plist")" == false ]]
      fi
      for profile in "${profiles[@]}"; do
        uuid="$(/usr/libexec/PlistBuddy -c 'Print UUID' "${scratch}/${profile}.plist")"
        grep -qx "${profile}_PROFILE_UUID=${uuid}" "${scratch}/archive.args"
        if [[ "${failure}" != archive ]]; then
          bundle_id=com.mikemcquaid.MinMaxCal
          [[ "${profile}" == WATCHOS ]] && bundle_id+=.watchkitapp
          [[ "$(/usr/libexec/PlistBuddy -c "Print :provisioningProfiles:${bundle_id}" "${scratch}/export.plist")" == "${uuid}" ]]
        fi
      done
    done
  done
done
# Simulate main moving while Xcode archives the private build.
cat >"${scratch}/bin/gh" <<'GITHUB'
#!/bin/bash
set -euo pipefail
[[ "$*" == 'api repos/test/repo/git/ref/heads/main --jq .object.sha' ]]
[[ "$(cat "${TESTFLIGHT_TEST_DIRECTORY}/calls")" == archive ]]
[[ "${TEST_MAIN}" != unavailable ]]
echo "${TEST_MAIN}"
GITHUB
chmod +x "${scratch}/bin/gh"
tested="$(git rev-parse HEAD)"
for TEST_MAIN in "${tested}" newer unavailable; do
  export TEST_MAIN
  rm -f "${scratch}/calls"
  : >"${scratch}/output"
  if GITHUB_SHA=event-default-sha GITHUB_REPOSITORY=test/repo GITHUB_EVENT_NAME=workflow_run GITHUB_OUTPUT="${scratch}/output" \
    TESTFLIGHT_TEST_FAILURE=none script/testflight --internal >"${scratch}/run.log" 2>&1; then
    [[ "${TEST_MAIN}" != unavailable ]]
  else
    [[ "${TEST_MAIN}" == unavailable ]] || exit 1
  fi
  if [[ "${TEST_MAIN}" == "${tested}" ]]; then
    [[ "$(cat "${scratch}/calls")" == $'archive\nupload' ]]
  else
    [[ "$(cat "${scratch}/calls")" == archive ]]
  fi
  if [[ "${TEST_MAIN}" == newer ]]; then
    grep -qx 'superseded=true' "${scratch}/output"
  fi
done
unset TESTFLIGHT_PLATFORM
echo 'TestFlight script tests passed'

ruby Tests/TestFlightAutomationTests.rb
