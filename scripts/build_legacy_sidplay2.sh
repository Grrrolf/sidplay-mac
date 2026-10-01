#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== Building Legacy Emulation Core (libsidplay2 + reSID) ==="
cd "${ROOT_DIR}"

OBJ_DIR="${ROOT_DIR}/build/legacy_sidplay2_objs"
mkdir -p "${OBJ_DIR}"
mkdir -p "${ROOT_DIR}/libs"

SRCS=(
    "libsidplay2/event.cpp"
    "libsidplay2/config.cpp"
    "libsidplay2/mixer.cpp"
    "libsidplay2/mos656x/mos656x.cpp"
    "libsidplay2/mos6510/mos6510.cpp"
    "libsidplay2/mos6526/mos6526.cpp"
    "libsidplay2/player.cpp"
    "libsidplay2/psiddrv.cpp"
    "libsidplay2/reloc65.cpp"
    "libsidplay2/resid/resid-builder.cpp"
    "libsidplay2/resid/resid.cpp"
    "libsidplay2/sid6526/sid6526.cpp"
    "libsidplay2/sidplay2.cpp"
    "libsidplay2/sidtune/IconInfo.cpp"
    "libsidplay2/sidtune/InfoFile.cpp"
    "libsidplay2/sidtune/MUS.cpp"
    "libsidplay2/sidtune/p00.cpp"
    "libsidplay2/sidtune/PP20.cpp"
    "libsidplay2/sidtune/prg.cpp"
    "libsidplay2/sidtune/PSID.cpp"
    "libsidplay2/sidtune/SidTune.cpp"
    "libsidplay2/sidtune/SidTuneTools.cpp"
    "libsidplay2/xsid/xsid.cpp"
    "resid/envelope.cc"
    "resid/extfilt.cc"
    "resid/filter.cc"
    "resid/pot.cc"
    "resid/sid.cc"
    "resid/version.cc"
    "resid/voice.cc"
    "resid/wave.cc"
    "resid/wave6581__ST.cc"
    "resid/wave6581_P_T.cc"
    "resid/wave6581_PS_.cc"
    "resid/wave6581_PST.cc"
    "resid/wave8580__ST.cc"
    "resid/wave8580_P_T.cc"
    "resid/wave8580_PS_.cc"
    "resid/wave8580_PST.cc"
    "libsidplay2/LegacySidEngine.cpp"
)

INCLUDES=(
    "-I${ROOT_DIR}"
    "-I${ROOT_DIR}/libsidplay2/include"
    "-I${ROOT_DIR}/libsidplay2/include/sidplay"
    "-I${ROOT_DIR}/libsidplay2/include/sidplay/builders"
    "-I${ROOT_DIR}/libsidplay2"
    "-I${ROOT_DIR}/resid"
)

CFLAGS=(
    "-O2"
    "-std=c++17"
    "-fPIC"
    "-fvisibility=hidden"
    "-mmacosx-version-min=14.0"
    "-arch" "arm64"
    "-arch" "x86_64"
    "-Wno-everything"
)

OBJS=()

for src in "${SRCS[@]}"; do
    filename=$(basename "${src}")
    dirprefix=$(basename "$(dirname "${src}")")
    base="${filename%.*}"
    obj="${OBJ_DIR}/${dirprefix}_${base}.o"
    OBJS+=("${obj}")

    # Recompile if source or interface header is newer than object file
    HEADER_DEP="${ROOT_DIR}/Source/AudioCore/ISidEngine.h"
    if [ ! -f "${obj}" ] || [ "${src}" -nt "${obj}" ] || [ "${HEADER_DEP}" -nt "${obj}" ]; then
        clang++ -c "${CFLAGS[@]}" "${INCLUDES[@]}" "${src}" -o "${obj}"
    fi
done

DYLIB_OUT="${ROOT_DIR}/libs/liblegacy_sidplay2.dylib"
echo "Linking ${DYLIB_OUT}..."
clang++ -dynamiclib \
    -install_name "@rpath/liblegacy_sidplay2.dylib" \
    -mmacosx-version-min=14.0 \
    -arch arm64 \
    -arch x86_64 \
    "${OBJS[@]}" \
    -o "${DYLIB_OUT}"

codesign --force --sign - "${DYLIB_OUT}" 2>/dev/null || true

echo "Legacy engine built successfully: $(ls -lh "${DYLIB_OUT}" | awk '{print $5, $9}')"
