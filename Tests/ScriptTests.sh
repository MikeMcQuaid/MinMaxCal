#!/bin/bash
# Check script failure handling without compiling or changing the real app.
set -euo pipefail

cd "$(dirname "$0")/.."
scratch="$(mktemp -d "${PWD}/.test-scratch/build.XXXXXX")"
trap 'rm -rf "${scratch}"' EXIT
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
exit "${BUILD_TEST_STATUS}"
BUILDER
chmod +x "${scratch}/bin/"* "${scratch}/script/"*

export PATH="${scratch}/bin:${PATH}"
export BUILD_TEST_STATUS=65
if "${scratch}/script/build" >"${scratch}/failure.log" 2>&1; then
  echo 'Build failure was hidden by an existing app bundle' >&2
  exit 1
fi

export BUILD_TEST_STATUS=0
"${scratch}/script/build" >"${scratch}/success.log" 2>&1
for log in failure success; do
  for stream in stdout stderr; do
    grep -q "Build diagnostic on ${stream}" "${scratch}/${log}.log"
  done
done
echo 'Build script tests passed'

cp script/style "${scratch}/script/style"
mkdir -p "${scratch}/App/Icons/AppIcon.icon/Assets" \
  "${scratch}/App/Assets.xcassets/MenuBarIcon.imageset" "${scratch}/.github/workflows"
touch "${scratch}/AGENTS.md"
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
echo 'Style script tests passed'
