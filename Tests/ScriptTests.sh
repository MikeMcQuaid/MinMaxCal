#!/bin/bash
# Check script failure handling without compiling or changing the real app.
set -euo pipefail

cd "$(dirname "$0")/.."
scratch="$(mktemp -d "${PWD}/.test-scratch/build.XXXXXX")"
trap '/bin/rm -rf "${scratch}"' EXIT
mkdir -p "${scratch}/script" "${scratch}/bin" "${scratch}/MinMaxCal.xcodeproj" \
  "${scratch}/.build/DerivedData/Build/Products/Release/MinMaxCal.app"
cp script/build "${scratch}/script/build"
ln -s .build/DerivedData/Build/Products/Release/MinMaxCal.app "${scratch}/MinMaxCal.app"
for command in version xcodegen; do
  printf '#!/bin/bash\nexit 0\n' >"${scratch}/bin/${command}"
done
cp "${scratch}/bin/version" "${scratch}/script/version"
cat >"${scratch}/bin/xcodebuild" <<'BUILDER'
#!/bin/bash
echo 'Build diagnostic on stdout'
echo 'Build diagnostic on stderr' >&2
while [[ "$1" != -configuration ]]; do shift || exit 1; done
[[ "$2" == "${XCODE_CONFIGURATION:-Release}" ]] || exit 1
exit "${BUILD_TEST_STATUS}"
BUILDER
chmod +x "${scratch}/bin/"* "${scratch}/script/"*

export PATH="${scratch}/bin:${PATH}"
unset XCODE_CONFIGURATION
export BUILD_TEST_STATUS=65
if "${scratch}/script/build" >"${scratch}/failure.log" 2>&1; then
  echo 'Build failure was hidden by an existing app bundle' >&2
  exit 1
fi

export BUILD_TEST_STATUS=0
"${scratch}/script/build" >"${scratch}/success.log" 2>&1
grep -Fqx '.build/DerivedData/Build/Products/Release/MinMaxCal.app' "${scratch}/success.log"
mkdir -p "${scratch}/.build/DerivedData/Build/Products/Debug/MinMaxCal.app"
XCODE_CONFIGURATION=Debug "${scratch}/script/build" >"${scratch}/debug.log" 2>&1
grep -Fqx '.build/DerivedData/Build/Products/Debug/MinMaxCal.app' "${scratch}/debug.log"
for log in failure success; do
  for stream in stdout stderr; do
    grep -q "Build diagnostic on ${stream}" "${scratch}/${log}.log"
  done
done
echo 'Build script tests passed'

cp script/install "${scratch}/script/install"
export INSTALL_TEST_LOG="${scratch}/install-commands.log"
for command in osascript pkill pgrep sleep rm ditto open; do
  cat >"${scratch}/bin/${command}" <<'INSTALLER'
#!/bin/bash
set -euo pipefail
echo "${0##*/} $*" >>"${INSTALL_TEST_LOG}"
case "${0##*/}" in
  pkill | pgrep)
    [[ "$*" == "-x -u ${UID} MinMaxCal" ]]
    [[ -f "${INSTALL_TEST_LOG}.running" ]]
    ;;
  sleep)
    if [[ "${INSTALL_TEST_STUCK:-}" == 1 ]]; then
      /bin/sleep "$@"
    else
      /bin/rm -f "${INSTALL_TEST_LOG}.running"
    fi
    ;;
  rm)
    [[ "$*" == '-rf /Applications/MinMaxCal.app' ]]
    [[ ! -f "${INSTALL_TEST_LOG}.running" ]]
    ;;
  ditto)
    [[ "$*" == ".build/DerivedData/Build/Products/${XCODE_CONFIGURATION:-Release}/MinMaxCal.app /Applications/MinMaxCal.app" ]]
    [[ ! -f "${INSTALL_TEST_LOG}.running" ]]
    ;;
  open)
    [[ "$*" == '-n /Applications/MinMaxCal.app' ]]
    exit "${INSTALL_TEST_OPEN_STATUS:-0}"
    ;;
esac
INSTALLER
  chmod +x "${scratch}/bin/${command}"
done

touch "${INSTALL_TEST_LOG}"
export BUILD_TEST_STATUS=65
if "${scratch}/script/install" >"${scratch}/install.log" 2>&1; then
  echo 'Install ignored a build failure' >&2
  exit 1
fi
[[ ! -s "${INSTALL_TEST_LOG}" ]]
for stream in stdout stderr; do
  grep -q "Build diagnostic on ${stream}" "${scratch}/install.log"
done

export BUILD_TEST_STATUS=0
for configuration in Release Debug; do
  : >"${INSTALL_TEST_LOG}"
  touch "${INSTALL_TEST_LOG}.running"
  XCODE_CONFIGURATION="${configuration}" "${scratch}/script/install" >"${scratch}/install.log" 2>&1
  for stream in stdout stderr; do
    grep -q "Build diagnostic on ${stream}" "${scratch}/install.log"
  done
  grep -q '^pkill ' "${INSTALL_TEST_LOG}"
  grep -q '^sleep ' "${INSTALL_TEST_LOG}"
  grep -q '^open ' "${INSTALL_TEST_LOG}"
done
"${scratch}/script/install" >"${scratch}/install.log" 2>&1

if INSTALL_TEST_OPEN_STATUS=1 "${scratch}/script/install" >"${scratch}/install.log" 2>&1; then
  echo 'Install ignored a launch failure' >&2
  exit 1
fi
if grep -q '^Installed ' "${scratch}/install.log"; then
  echo 'Install reported success after a launch failure' >&2
  exit 1
fi

touch "${INSTALL_TEST_LOG}.running"
: >"${INSTALL_TEST_LOG}"
if INSTALL_TEST_STUCK=1 "${scratch}/script/install" >"${scratch}/install.log" 2>&1; then
  echo 'Install replaced an app that had not stopped' >&2
  exit 1
fi
if grep -Eq '^(rm|ditto|open) ' "${INSTALL_TEST_LOG}"; then
  echo 'Install replaced an app that had not stopped' >&2
  exit 1
fi
grep -q 'did not stop' "${scratch}/install.log"
echo 'Install script tests passed'
/bin/rm -f "${scratch}/bin/rm"

cp script/style "${scratch}/script/style"
mkdir -p "${scratch}/App/Icons/AppIcon.icon/Assets" \
  "${scratch}/App/Assets.xcassets/MenuBarIcon.imageset" "${scratch}/.github/workflows"
touch "${scratch}/AGENTS.md"
cat >"${scratch}/README.md" <<'README'
## Before
- Another section
## ✨ Features
- First feature
  wrapped description
* Second feature
+ Third feature
- Fourth feature
- Fifth feature
## After
- Another section
README
ln -s AGENTS.md "${scratch}/CLAUDE.md"
echo app >"${scratch}/App/Icons/AppIcon.icon/Assets/AppMark.svg"
echo menu >"${scratch}/App/Assets.xcassets/MenuBarIcon.imageset/Leaf.svg"
for command in shellcheck shfmt actionlint zizmor swiftformat swiftlint; do
  cat >"${scratch}/bin/${command}" <<'LINTER'
#!/bin/bash
if [[ "${STYLE_TEST_FAILURE}" == swiftformat-lint && "${0##*/}" == swiftformat && "$1" == --lint ]]; then
  exit 1
fi
[[ "${0##*/}" != "${STYLE_TEST_FAILURE}" ]]
LINTER
  chmod +x "${scratch}/bin/${command}"
done

for command in shellcheck shfmt actionlint zizmor swiftformat swiftlint swiftformat-lint; do
  export STYLE_TEST_FAILURE="${command}"
  if "${scratch}/script/style" --fix >"${scratch}/style.log" 2>&1; then
    echo "Style failure was hidden: ${command}" >&2
    exit 1
  fi
done
export STYLE_TEST_FAILURE=''
"${scratch}/script/style" --fix
cp "${scratch}/README.md" "${scratch}/README.five.md"
for marker in - '*' +; do
  sed "/^## After/i\\
${marker} Sixth feature
" "${scratch}/README.five.md" >"${scratch}/README.md"
  for option in '' --fix; do
    if "${scratch}/script/style" "${option}" >"${scratch}/style.log" 2>&1; then
      echo 'Style accepted more than five README features' >&2
      exit 1
    fi
    grep -q 'README.md: Features must contain at most 5 bullets' "${scratch}/style.log"
  done
done
sed '/^- Fifth feature/d; s/## ✨ Features/## Features/' "${scratch}/README.five.md" >"${scratch}/README.md"
"${scratch}/script/style"
for heading in '## Renamed' '## Upcoming Features'; do
  echo "${heading}" >"${scratch}/README.md"
  for option in '' --fix; do
    if "${scratch}/script/style" "${option}" >"${scratch}/style.log" 2>&1; then
      echo "Style accepted a missing README Features section: ${heading}" >&2
      exit 1
    fi
    grep -q 'README.md: Features section is missing' "${scratch}/style.log"
  done
done
for fence in '```' '~~~' '   ````'; do
  printf '%smarkdown\n## Features\n%s\n' "${fence}" "${fence}" >"${scratch}/README.md"
  for option in '' --fix; do
    if "${scratch}/script/style" "${option}" >"${scratch}/style.log" 2>&1; then
      echo 'Style accepted a fenced README Features heading' >&2
      exit 1
    fi
    grep -q 'README.md: Features section is missing' "${scratch}/style.log"
  done
  awk -v fence="${fence}" '
    /^## After/ { print "\nExample:\n\n" fence "markdown\n## Example\n- Example bullet\n" fence "\n- Sixth feature" }
    { print }
  ' "${scratch}/README.five.md" >"${scratch}/README.fenced.md"
  cp "${scratch}/README.fenced.md" "${scratch}/README.md"
  for option in '' --fix; do
    if "${scratch}/script/style" "${option}" >"${scratch}/style.log" 2>&1; then
      echo 'Style let a fenced heading hide a sixth README feature' >&2
      exit 1
    fi
    grep -q 'README.md: Features must contain at most 5 bullets (found 6)' "${scratch}/style.log"
  done
  sed '/^- Sixth feature/d' "${scratch}/README.fenced.md" >"${scratch}/README.md"
  for option in '' --fix; do
    "${scratch}/script/style" "${option}"
  done
done
awk '{ print } END { for (line = NR; line < 200; line++) print "" }' \
  "${scratch}/README.five.md" >"${scratch}/README.md"
"${scratch}/script/style"
echo '' >>"${scratch}/README.md"
for option in '' --fix; do
  if "${scratch}/script/style" "${option}" >"${scratch}/style.log" 2>&1; then
    echo 'Style accepted more than 200 README lines' >&2
    exit 1
  fi
  grep -q 'README.md: must contain at most 200 lines' "${scratch}/style.log"
done
cp "${scratch}/README.five.md" "${scratch}/README.md"
printf '%072d\n\n' 0 >>"${scratch}/README.md"
for indentation in '' ' ' '  ' '   '; do
  for spacing in '' ' '; do
    printf '%s[link]:%shttps://example.com/%080d\n' "${indentation}" "${spacing}" 0 >>"${scratch}/README.md"
  done
done
for option in '' --fix; do
  "${scratch}/script/style" "${option}"
done
printf '%073d\n' 0 >>"${scratch}/README.md"
for option in '' --fix; do
  if "${scratch}/script/style" "${option}" >"${scratch}/style.log" 2>&1; then
    echo 'Style accepted an unwrapped README line' >&2
    exit 1
  fi
  grep -q 'README.md:.*longer than 72 characters' "${scratch}/style.log"
done
echo 'Style script tests passed'

bash Tests/TestFlightTests.sh
