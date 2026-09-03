# App Store Connect 등록 문안 — 한쪽 1.0

App Store Connect에 그대로 붙여넣는 용도. 글자 수 제한은 Apple 기준.

## 기본 정보

| 항목 | 값 |
|---|---|
| 앱 이름 (30자) | **한쪽 - 초성 메모장** — "한쪽" 단독은 iOS 기존 앱(HWP 뷰어)이 선점. 안 되면 "한쪽 메모" → "한쪽: 초성으로 찾는 메모장" 순으로 시도. Mac 표시명은 그대로 "한쪽" |
| 부제 (30자) | 화면 한쪽에 종이 한 장, 메뉴바 메모 |
| 번들 ID | `kr.hurdlers.Hanjjok` |
| SKU | `hanjjok-mac` |
| 기본 언어 | 한국어 |
| 카테고리 | 생산성 (보조: 유틸리티) |
| 가격 | 무료 |
| 연령 등급 | 4+ |
| 저작권 | © 2026 Joonhyuk Yoo |
| 판매 지역 | 전체 |

## 프로모션 텍스트 (170자, 심사 없이 수정 가능)

`ㅅㅇㄷ`만 쳐도 찾아지는 메모장. 메뉴바에서 ⌥Space 한 번이면 화면 한쪽에 종이 한 장이 나옵니다. 계정도, 서버도, 동기화도 없이 전부 내 Mac 안에만.

## 설명 (4000자)

> 첫 두 줄이 목록에서 잘리지 않고 보이는 전부다.

**초성으로 찾는 맥 메모장.** `ㅅㅇㄷ`를 치면 "사이드노트"가 나오고, `사이ㄷ`처럼 아직 조합 중인 글자로도 결과가 끊기지 않습니다.

카카오톡 '나와의 채팅'에 메모하던 습관을 Mac 메뉴바로 옮겼습니다. ⌥Space를 누르면 화면 한쪽에서 종이 한 장이 미끄러져 나오고, 적고, Esc로 닫으면 하던 일로 돌아갑니다. 생각에서 기록까지 1초.

**한쪽이 하는 것**
- 초성·부분 검색 — 한글 조합 중에도 결과가 유지됩니다
- 시간순 타임라인 — 폴더 계층 없이 위에서 아래로 쌓입니다
- `#태그`로 분류, 1단계 폴더로 정리
- 가벼운 마크다운 — 제목, 굵게, 인용, 불릿, 체크리스트
- 체크리스트는 카드에서 바로 완료 토글
- 라이트는 한지, 다크는 먹 — 시스템 설정을 따릅니다
- 본문 글꼴 마루부리 / Pretendard 전환
- 전체 메모를 마크다운 파일로 내보내기 — 락인 없음

**한쪽이 안 하는 것**
- 계정, 서버, 동기화, 광고, 분석. 네트워크에 연결하지 않습니다.
- 모든 메모는 이 Mac에만 있습니다.

**메뉴바 앱입니다.** Dock에 아이콘이 없습니다. 메뉴바의 아이콘을 누르거나 ⌥Space(설정에서 변경 가능)로 엽니다. 로그인 시 자동 실행을 켤 수 있습니다.

macOS 14 Sonoma 이상.

## 키워드 (100자, 쉼표 구분, 공백 없이)

```
메모,초성검색,한글,메모장,스크래치패드,마크다운,메뉴바,빠른메모,체크리스트,노트,한지
```

## URL

| 항목 | 값 |
|---|---|
| 개인정보처리방침 URL (필수) | `https://dbwnsgur741.github.io/hanjjok/privacy.html` |
| 지원 URL (필수) | `https://github.com/dbwnsgur741/hanjjok/issues` |
| 마케팅 URL (선택) | `https://dbwnsgur741.github.io/hanjjok/` (hanjjok.app 등록 후 교체) |

## 앱 개인정보 (App Privacy)

**"데이터를 수집하지 않음"** — 전 항목. 네트워크 코드가 없으므로 사실 그대로다.

## 심사 메모 (App Review Information → Notes)

> 이 메모가 없으면 "앱이 실행되지 않는다"로 반려될 수 있다. 메뉴바 앱의 가장 흔한 반려 사유.

```
이 앱은 메뉴바 상주 앱입니다 (LSUIElement = true). Dock에 아이콘이 나타나지 않는 것이 정상입니다.

실행 방법:
1. 앱을 열면 메뉴바 오른쪽에 아이콘이 나타납니다.
2. 아이콘을 클릭하거나 ⌥Space(Option+Space)를 누르면 화면 오른쪽 가장자리에서 메모 패널이 나타납니다.
3. 패널에 텍스트를 입력하고 Enter로 저장합니다. Esc로 패널을 닫습니다.
4. 메뉴바 아이콘을 우클릭하면 설정·전체 내보내기·종료 메뉴가 있습니다.

네트워크 통신이 없으며 모든 데이터는 로컬 샌드박스 컨테이너에 저장됩니다.
```

## 스크린샷 (Mac: 1280×800 이상, 최소 1장, 권장 4~5장)

1. 라이트(한지) — 메모 몇 장 쌓인 타임라인 + 패널 전체
2. **초성 검색 중** — `ㅅㅇㄷ` 입력, 결과 하이라이트 (가장 중요)
3. 다크(먹) — 같은 화면
4. 체크리스트 카드 + 폴더 칩 바
5. 설정 창 (단축키·글꼴·화면 모드)

찍는 법: ⌥Space로 패널 → ⌘⇧4 → Space → 패널 클릭 (창 단위 캡처, 그림자 포함). Retina라 2560×1600으로 나오며 그대로 업로드 가능.

## 빌드 업로드 (Task 5 — Xcode 계정 재로그인 후)

Xcode에서: Product → Archive → Distribute App → App Store Connect → Upload.
또는 CLI:

```bash
xcodegen generate
xcodebuild -project Hanjjok.xcodeproj -scheme Hanjjok -configuration Release \
  -archivePath build/Hanjjok.xcarchive -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath build/Hanjjok.xcarchive -exportPath build/export \
  -exportOptionsPlist <method=app-store-connect, teamID=B868S3249K> -allowProvisioningUpdates
```
