# Hanji 디자인 토큰 (목업 승인: 2026-08-31)

## 색

| 토큰 | 라이트(한지) | 다크(먹) |
|---|---|---|
| paper (바탕) | `#E2D9C2` | `#1C1A17` |
| card (떡메모지) | `#EFE8D6` | `#25221E` |
| ink (본문) | `#2A2620` | `#E8E0CE` |
| inkSoft (시각·라벨·힌트) | `#6E6559` | `#948B7A` |
| inkMute (플레이스홀더) | `#8A8070` | `#736B5D` |
| jjok (쪽빛 액센트) | `#274C77` | `#7EA6CE` |
| jjokWash (검색 매치 바탕) | `rgba(39,76,119,.16)` | `rgba(126,166,206,.20)` |
| tag 청 | `#2E6B63` | `#6FA79C` |
| tag 적 | `#9C3B33` | `#C97F73` |
| tag 황 | `#8A6420` | `#C6A05C` |
| tag 백 | `#5F6A70` | `#9FAEB6` |
| tag 흑 | `#3E3B4A` | `#9A93AB` |
| 이음매 위 / 아래 | `#2A2620` 24% / `#FFFBF0` 75% | `#000000` 45% / `#E8E0CE` 9% |
| 결 tint · 농도 | `#4A3D28` · 16% | `#D8CDB4` · 9% |
| 카드 그림자 | `0 1 1.5 rgba(60,48,30,.10)` + `0 0 0 .5 rgba(60,48,30,.07)` | `0 1 2 rgba(0,0,0,.34)` + `0 0 0 .5 rgba(232,224,206,.055)` |
| 태그 칩 바탕 | 태그색 12% 알파 | 동일 |

## 타이포·치수 (테마 공통)

| 항목 | 값 |
|---|---|
| 본문 | MaruBuri Regular 15pt / 행간 1.62 |
| 해시태그 | Pretendard SemiBold 12.5pt |
| 태그 칩 바탕 | 태그색 12% 알파 · r3 |
| 시각 (타임스탬프) | Pretendard Regular 10.5pt |
| 날짜 라벨 | Pretendard SemiBold 11pt · 자간 +0.1em |
| 검색 입력 | Pretendard Regular 14pt |
| 매치 · 본문 | jjok 16% 알파 바탕 · r2 |
| 매치 · 태그 | jjok 1px 테두리 |
| 카드 패딩 | 11 × 13 |
| 카드 반경 · 카드 간격 | 6 · 8 |
| 이음매 여백 | 위 22 · 아래 12 |
| 패널 좌우 여백 | 16 |
| 컴포저 | 13/16/15 · 필드 10×12 |
| 커서 | 2 × 19 · jjok |
| 줄바꿈 | keep-all (어절 유지) |
| 긴 메모 접기 (v1.5) | 접힘 본문 200pt(≈8줄) · 접기 임계 280pt(≈11줄) · 하단 페이드 44pt(card 투명→불투명) · "더 보기/접기" Pretendard SemiBold 11 + chevron 9 |
| 수정 푸터 (v1.5) | 힌트 Pretendard Regular 10.5 inkSoft · 버튼 Pretendard SemiBold 11, 패딩 3×9, r3 — 취소 inkSoft(호버 ink + inkSoft 8%), 저장 jjok + jjokWash(호버 jjok 26%) |
| 입력 규칙 힌트 (v1.5) | 컴포저 툴바 우측 Pretendard Regular 10.5 inkSoft, 한 줄 말줄임 |

## 결 (그레인)

한지 결은 **패널 전체를 덮는 알파 노이즈 한 장**으로 구현된다. 카드와 텍스트 위까지 같은 결이 지나가야 한 장의 종이로 읽힌다.

**기술 사양:**
- **소스**: 512×512 PNG 알파 노이즈 타일 (RGB는 흰색)
- **에셋 경로**: `Hanjjok/Resources/Textures/PaperGrain.png`
- **배치**: 256pt 타일로 반복 (@2x 화면에서 512px 소스)
- **마스킹**: 잉크색으로 마스킹 후 불투명도 적용
- **레이어 순서** (맨 아래부터):
  1. 바탕색 (`paper`)
  2. 카드들 (`card`)
  3. 텍스트 · 오브젝트
  4. 맨 위 결 오버레이 (tint + 농도)
    - 라이트: `#4A3D28` @ 16%
    - 다크: `#D8CDB4` @ 9%

**필터 원본** (참고, 이미 구워짐 — `docs/design/src/HanjiGrain.svg`):
```
SVG 512×512, filterUnits/primitiveUnits = userSpaceOnUse, color-interpolation-filters = sRGB
  feTurbulence fractalNoise  baseFrequency 0.90         numOctaves 4  seed 17  stitchTiles
    → 잔결(fine): 고운 노이즈
  feTurbulence fractalNoise  baseFrequency 0.004 0.22   numOctaves 1  seed 5   stitchTiles
    → 섬유(fibre): 세로로 긴 섬유 문양
  feComposite  arithmetic    k1=0 k2=0.88 k3=0.12 k4=0
    → 8:2 혼합 (잔결 88% + 섬유 12%)
  feColorMatrix  RGB = 흰색 고정, alpha = 1.9·(R+G) − 1.6
    → 알파 채널 계산 (평균 0.31, 표준편차 0.22)
```

**구현 시 주의:**
- `feTurbulence`를 CSS `mask-image` data URI로 직접 사용하면 브라우저가 필터를 실행하지 않으므로, 이미 구운 PNG를 사용한다.
- SwiftUI: PNG를 `template image`로 로드하고 `.tint(_)`로 색상 적용, 불투명도 조정.
