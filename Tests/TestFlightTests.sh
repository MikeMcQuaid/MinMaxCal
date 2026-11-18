#!/bin/bash
# Check release gating, signing cleanup and uploads without credentials.
set -euo pipefail

cd "$(dirname "$0")/.."
ruby -ryaml <<'WORKFLOW'
workflow = YAML.load_file('.github/workflows/release.yml')
jobs = workflow.fetch('jobs')
release = jobs.fetch('release')
unless Array(release['needs']).include?('testflight')
  abort 'GitHub publication can run before TestFlight succeeds'
end
if release.fetch('if', '').match?(/\b(always|failure|cancelled)\s*\(/)
  abort 'GitHub publication bypasses successful dependencies'
end
testflight = jobs.fetch('testflight')
if Array(testflight['needs']).include?('release') || testflight.fetch('if', '').include?('needs.release')
  abort 'TestFlight depends on GitHub publication'
end
if testflight['continue-on-error'] || testflight.fetch('steps').any? { |step| step['continue-on-error'] }
  abort 'TestFlight failures can be ignored'
end
unless workflow.dig('concurrency', 'queue') == 'max' && workflow.dig('concurrency', 'group') == "${{ github.event_name == 'push' && format('minmaxcal-release-dry-run-{0}', github.ref) || 'minmaxcal-release' }}"
  abort 'Releases and private uploads must share a serial queue'
end
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
  expression = testflight.fetch('if').gsub(/\s+/, ' ')
  values.each { |key, value| expression = expression.gsub(key, value.inspect) }
  expected = !cancelled && if event == 'workflow_run'
    cause == 'push' && branch == 'main' && repo == 'local' && conclusion == 'success'
  else
    actor != 'dependabot[bot]' && build == 'success' && smoke == 'success'
  end
  abort "Unsafe TestFlight trigger: #{values}" unless eval(expression) == expected
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
prepare = steps.find { |step| step['id'] == 'prepare' }
abort 'Allocate an upload identity before archiving' unless prepare
restore = steps.index { |step| step.dig('with', 'pattern') == 'testflight-upload*' }
record = steps.index { |step| step.dig('with', 'name').to_s.start_with?('testflight-upload-') }
reservation = steps.index { |step| step.dig('with', 'name').to_s.start_with?('testflight-attempt-') }
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
esac
SECURITY
cat >"${scratch}/bin/xcodebuild" <<'XCODEBUILD'
#!/bin/bash
set -euo pipefail
echo /archive-concurrent.keychain-db >>"${TESTFLIGHT_TEST_DIRECTORY}/keychains"
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
[[ "$3" == */export/MinMaxCal.ipa ]]
[[ "$4" == --api-key && "$5" == KEY1234567 ]]
[[ "$6" == --api-issuer && "$7" == issuer ]]
[[ "$8" == --p8-file-path && "$(cat "$9")" == 'test API key' ]]
echo validate >>"${TESTFLIGHT_TEST_DIRECTORY}/calls"
[[ "${TESTFLIGHT_TEST_FAILURE}" != validate ]]
VALIDATOR
chmod +x "${scratch}/bin/"*

export RELEASE_VERSION=1.2.3 BUILD_NUMBER=42.2
unset APP_STORE_TEAM_ID APP_STORE_MACOS_PROFILE
export APP_STORE_KEY='test API key' APP_STORE_KEY_ID=KEY1234567 APP_STORE_ISSUER_ID=issuer
export APP_STORE_CERTIFICATES=dGVzdA== APP_STORE_CERTIFICATES_PASSWORD=password
for platform in IOS WATCHOS; do
  bundle_id=com.mikemcquaid.MinMaxCal
  [[ "${platform}" == WATCHOS ]] && bundle_id+=.watchkitapp
  plutil -create xml1 "${scratch}/${platform}.plist"
  /usr/libexec/PlistBuddy -c "Add :UUID string $(uuidgen)" \
    -c 'Add :TeamIdentifier array' -c 'Add :TeamIdentifier:0 string ABCDEFGHIJ' \
    -c 'Add :Entitlements dict' \
    -c "Add :Entitlements:application-identifier string OLDPREFIX1.${bundle_id}" \
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

for platform in IOS WATCHOS; do
  cp "${scratch}/${platform}.plist" "${scratch}/wrong-profile.plist"
  /usr/libexec/PlistBuddy -c 'Set :Entitlements:application-identifier OLDPREFIX1.com.example.OtherApp' \
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
  for profile in IOS WATCHOS; do
    uuid="$(/usr/libexec/PlistBuddy -c 'Print UUID' "${scratch}/${profile}.plist")"
    [[ ! -e "${HOME}/Library/Developer/Xcode/UserData/Provisioning Profiles/${uuid}.mobileprovision" ]]
  done
  rm -f "${scratch}/security.log"
done

for audience in public private dry-run; do
  mode=upload
  args=()
  [[ "${audience}" == private ]] && args=(--internal)
  if [[ "${audience}" == dry-run ]]; then
    mode="export"
    args=(--dry-run)
  fi
  for failure in list none create import archive export validate; do
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
    for profile in IOS WATCHOS; do
      uuid="$(/usr/libexec/PlistBuddy -c 'Print UUID' "${scratch}/${profile}.plist")"
      [[ ! -e "${HOME}/Library/Developer/Xcode/UserData/Provisioning Profiles/${uuid}.mobileprovision" ]]
    done
    if [[ "${failure}" == create || "${failure}" == import || "${failure}" == list ]]; then
      [[ ! -e "${scratch}/calls" ]]
      continue
    fi
    grep -qx MinMaxCal-iOS "${scratch}/archive.args"
    grep -qx generic/platform=iOS "${scratch}/archive.args"
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
      [[ "$(/usr/libexec/PlistBuddy -c 'Print :method' "${scratch}/export.plist")" == app-store-connect ]]
      [[ "$(/usr/libexec/PlistBuddy -c 'Print :destination' "${scratch}/export.plist")" == "${mode}" ]]
      internal=false
      [[ "${audience}" == private ]] && internal=true
      [[ "$(/usr/libexec/PlistBuddy -c 'Print :testFlightInternalTestingOnly' "${scratch}/export.plist")" == "${internal}" ]]
      [[ "$(/usr/libexec/PlistBuddy -c 'Print :teamID' "${scratch}/export.plist")" == ABCDEFGHIJ ]]
      [[ "$(/usr/libexec/PlistBuddy -c 'Print :manageAppVersionAndBuildNumber' "${scratch}/export.plist")" == false ]]
    fi
    for profile in IOS WATCHOS; do
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
echo 'TestFlight script tests passed'

ruby Tests/TestFlightAutomationTests.rb
