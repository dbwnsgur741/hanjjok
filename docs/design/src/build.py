#!/usr/bin/env python3
"""docs/design/mockup.html 빌드 — 한지 결 타일과 서브셋 폰트를 파일 안에 굽는다."""
import base64, pathlib, shutil, subprocess, sys

SCR = pathlib.Path(__file__).resolve().parent          # docs/design/src
ROOT = SCR.parents[2]                                   # 저장소 루트
OUT = SCR.parent / "mockup.html"
TPL = SCR / "mockup.tpl.html"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
FONTS = ROOT / "Hanji/Resources/Fonts"
# Pretendard 웹폰트 서브셋(woff2). 릴리스 zip 의 web/static/woff2-subset 를 가리킨다.
PRET = pathlib.Path("/tmp/pretendard/web/static/woff2-subset")
# pip install fonttools brotli — pyftsubset 이 PATH 에 없으면 모듈로 부른다.
PYFTSUBSET = (shutil.which("pyftsubset") and [shutil.which("pyftsubset")]
              or [sys.executable, "-m", "fontTools.subset"])

# ── 한지 결 ───────────────────────────────────────────────────────────────
# 잔결(fine) × 섬유(fibre) 두 층을 8:2로 섞고 알파만 남긴다.
# 512 유저유닛 = 256pt 타일(@2x). stitchTiles 로 이음매 없이 반복.
GRAIN = dict(gain=1.9, bias=-1.6, fine="0.90", fine_oct=4,
             fibre="0.004 0.22", fibre_oct=1, mix=0.88, seed_a=17, seed_b=5)

GRAIN_PNG   = SCR / "HanjiGrain.png"        # 512×512 알파 원본 (Task 8 Step 5 용)
GRAIN_EMBED = SCR / "HanjiGrain-embed.png"  # 목업 임베드용 (알파 32단계)


def grain_svg(g=GRAIN) -> str:
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
<filter id="h" x="0" y="0" width="512" height="512" filterUnits="userSpaceOnUse"
        primitiveUnits="userSpaceOnUse" color-interpolation-filters="sRGB">
  <feTurbulence type="fractalNoise" baseFrequency="{g['fine']}" numOctaves="{g['fine_oct']}"
                seed="{g['seed_a']}" stitchTiles="stitch" result="fine"/>
  <feTurbulence type="fractalNoise" baseFrequency="{g['fibre']}" numOctaves="{g['fibre_oct']}"
                seed="{g['seed_b']}" stitchTiles="stitch" result="fibre"/>
  <feComposite in="fine" in2="fibre" operator="arithmetic"
               k1="0" k2="{g['mix']}" k3="{round(1 - g['mix'], 3)}" k4="0" result="mix"/>
  <feColorMatrix in="mix" type="matrix"
                 values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  {g['gain']} {g['gain']} 0 0 {g['bias']}"/>
</filter>
<rect width="512" height="512" filter="url(#h)"/>
</svg>'''


def bake_grain():
    """SVG 필터를 실제 픽셀로 굽는다 — 브라우저의 feTurbulence 지원에 의존하지 않기 위해."""
    svg = SCR / "HanjiGrain.svg"
    svg.write_text(grain_svg(), encoding="utf-8")
    subprocess.run([CHROME, "--headless", "--disable-gpu", "--window-size=512,512",
                    "--force-device-scale-factor=1", "--default-background-color=00000000",
                    f"--screenshot={GRAIN_PNG}", f"file://{svg}"], capture_output=True, check=True)
    # 알파를 32단계로 줄여 파일 크기를 절반으로. RGB는 흰색으로 고정해
    # 브라우저가 mask 를 alpha 로 읽든 luminance 로 읽든 같은 결과가 나오게 한다.
    a = SCR / "_alpha.png"
    subprocess.run(["magick", str(GRAIN_PNG), "-alpha", "extract", "-posterize", "32",
                    "-depth", "8", str(a)], check=True)
    subprocess.run(["magick", "-size", "512x512", "xc:white", str(a), "-alpha", "off",
                    "-compose", "CopyOpacity", "-composite", "-strip",
                    "-define", "png:compression-level=9", str(GRAIN_EMBED)], check=True)
    a.unlink()


def ks_hangul() -> str:
    """KS X 1001 완성형 한글 — 문구를 나중에 손봐도 글자가 빠지지 않도록 여유 있게."""
    out = []
    for cp in range(0xAC00, 0xD7A4):
        ch = chr(cp)
        try:
            ch.encode("euc-kr")
        except UnicodeEncodeError:
            continue
        out.append(ch)
    return "".join(out)


def subset(src, dst, textfile):
    subprocess.run([*PYFTSUBSET, str(src), f"--text-file={textfile}",
                    "--layout-features=kern,liga,calt,ccmp", "--flavor=woff2",
                    "--desubroutinize", f"--output-file={dst}"], check=True)


def b64(p): return base64.b64encode(pathlib.Path(p).read_bytes()).decode("ascii")


def main():
    tpl = TPL.read_text(encoding="utf-8")
    bake_grain()

    charfile = SCR / "chars.txt"
    jamo = "".join(chr(c) for c in range(0x3131, 0x3164))
    charfile.write_text(tpl + ks_hangul() + jamo + "0123456789", encoding="utf-8")

    mb = SCR / "MaruBuri-Regular.subset.woff2"
    subset(FONTS / "MaruBuri-Regular.otf", mb, charfile)

    grain_uri = f'url(data:image/png;base64,{b64(GRAIN_EMBED)})'
    html = (tpl.replace("__GRAIN__", grain_uri)
               .replace("__MB_R__", b64(mb))
               .replace("__PT_R__", b64(PRET / "Pretendard-Regular.subset.woff2"))
               .replace("__PT_SB__", b64(PRET / "Pretendard-SemiBold.subset.woff2")))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(html, encoding="utf-8")

    for label, p in [("grain (원본 512 alpha)", GRAIN_PNG), ("grain (임베드)", GRAIN_EMBED),
                     ("MaruBuri subset", mb),
                     ("Pretendard R", PRET / "Pretendard-Regular.subset.woff2"),
                     ("Pretendard SB", PRET / "Pretendard-SemiBold.subset.woff2"),
                     ("mockup.html", OUT)]:
        print(f"{label:26s} {pathlib.Path(p).stat().st_size/1024:8.1f} KB")


if __name__ == "__main__":
    main()
