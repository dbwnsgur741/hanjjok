# Galpi (갈피) Mac App Store 무료 런칭 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hanji를 Galpi(갈피)로 리브랜딩하고 App Sandbox·코드사인·앱 아이콘을 갖춰 Mac App Store에 무료 앱으로 제출 가능한 상태로 만든다.

**Architecture:** 기존 DDD-lite 레이어(Domain/Data/PanelKit/App)는 그대로 둔다. 변경은 세 축뿐 — ① 이름·경로·문자열 리네임, ② `.entitlements` 추가와 서명 설정(둘 다 `project.yml`을 통해 XcodeGen이 생성), ③ 에셋 카탈로그 신규 도입. 기능 코드는 건드리지 않는다.

**Tech Stack:** Swift 5.10, SwiftUI + AppKit(NSPanel), GRDB 7.x, KeyboardShortcuts(sindresorhus), XcodeGen, macOS 14+

**Spec:** `docs/superpowers/specs/2026-08-31-hanji-design.md` (§3 확정 정책, §11 미해결 항목)

## Global Constraints

- 최소 타깃 **macOS 14 (Sonoma)**, Swift tools 5.10
- **Domain 패키지는 Foundation 외 import 금지**
- **네트워크 코드 금지** — 완전 로컬, 텔레메트리 없음. 이 제약이 App Store 개인정보 라벨을 전부 "수집 안 함"으로 만들어주는 핵심 자산이므로 절대 깨지 않는다
- 앱은 `LSUIElement=true` 메뉴바 상주 앱 — Dock 아이콘 없음
- UI 문자열은 한국어
- 번들 ID는 **`kr.hurdlers.Galpi`로 확정** — App Store Connect 레코드 생성 후에는 영구 고정되어 변경 불가
- 저장 위치는 샌드박스 컨테이너 내부: `~/Library/Containers/kr.hurdlers.Galpi/Data/Library/Application Support/Galpi/galpi.sqlite`
- 폰트 MaruBuri·Pretendard 모두 OFL — `Resources/Fonts/LICENSE.txt`를 반드시 번들에 동봉 유지
- `project.yml`이 단일 진실 공급원. `Galpi.xcodeproj`와 `Galpi/Info.plist`는 **생성물이며 `.gitignore` 대상**이다. 절대 직접 편집하지 않는다
- **2026년 4월 28일부터 App Store는 최신 SDK 빌드만 받는다.** 제출 시점의 Xcode를 최신으로 유지할 것 (`xcodebuild -version`으로 확인). 배포 타깃 macOS 14는 그대로 둬도 무방하다 — SDK 버전과 배포 타깃은 별개다

**빌드·테스트 명령 (전 태스크 공통):**

```bash
# 패키지 테스트
swift test --package-path Packages/Domain
swift test --package-path Packages/Data

# 앱 빌드
xcodegen generate
xcodebuild -project Galpi.xcodeproj -scheme Galpi -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/Galpi.app
```

---

## Task 0: 외부 선행 조건 (코드 아님 — 사람이 처리)

이 항목들은 코드 작업과 병렬로 진행 가능하지만, **Task 5(코드사인) 전까지 1·2번이 완료되어야 한다.**

- [ ] **Apple Developer Program 가입** — 연 $99. 무료 앱이어도 필수. 개인/사업자 선택 시 사업자는 D-U-N-S 번호가 필요해 2~4주 걸리므로, 빠르게 가려면 개인 명의로 등록한다
- [ ] **도메인 등록** — `galpi.com`, `galpi.app`
- [ ] **App Store Connect에서 앱 이름 "갈피" 선점** — 레코드 생성만으로 180일간 확보된다. 번들 ID `kr.hurdlers.Galpi` 등록은 **Task 2 완료 후**에 할 것 (한 번 만들면 못 바꾼다)
- [ ] **개인정보처리방침 페이지 게시** — `galpi.com/privacy`. 내용은 한 문단이면 충분하다: "갈피는 어떠한 데이터도 수집·전송하지 않습니다. 모든 메모는 사용자의 Mac에만 저장되며 네트워크 통신을 하지 않습니다." App Store Connect 제출 시 URL 입력란이 필수다

---

## Task 1: Domain·Data 계층 리네임 (테스트 주도)

리네임 중 **유일하게 자동 테스트가 잡아주는 구간**이다. 사용자에게 보이는 산출물 문자열(내보내기 헤더, 백업 파일명)이 여기 있다.

**Files:**
- Modify: `Packages/Domain/Sources/Domain/MarkdownExporter.swift:16`
- Modify: `Packages/Data/Sources/Data/BackupScheduler.swift:17,23`
- Test: `Packages/Domain/Tests/DomainTests/MarkdownExporterTests.swift:18,33`
- Test: `Packages/Data/Tests/DataTests/BackupSchedulerTests.swift:10,16,36,56,57,66`

**Interfaces:**
- Consumes: 없음 (첫 태스크)
- Produces: 내보내기 헤더 문자열 `"# 갈피 전체 내보내기\n"`, 백업 파일명 규칙 `galpi-YYYY-MM-DD.sqlite`. Task 2의 App 계층이 이 규칙에 의존한다

- [x] **Step 1: 테스트 기대값을 새 이름으로 고친다 (실패 유도)**

`Packages/Domain/Tests/DomainTests/MarkdownExporterTests.swift` — 18행과 33행의 `한지`를 `갈피`로:

```swift
        # 갈피 전체 내보내기
```

```swift
        XCTAssertEqual(MarkdownExporter.export([], timeZone: .current), "# 갈피 전체 내보내기\n")
```

`Packages/Data/Tests/DataTests/BackupSchedulerTests.swift` — 파일 내 `hanji`를 전부 `galpi`로:

```bash
sed -i '' 's/hanji/galpi/g' Packages/Data/Tests/DataTests/BackupSchedulerTests.swift
```

이러면 36·56·57·66행의 기대 파일명이 `galpi-2026-08-31.sqlite` 등으로 바뀐다.

- [x] **Step 2: 테스트를 돌려 실패를 확인한다**

```bash
swift test --package-path Packages/Domain --filter MarkdownExporterTests
swift test --package-path Packages/Data --filter BackupSchedulerTests
```

Expected: 두 스위트 모두 FAIL.
- `MarkdownExporterTests` → `XCTAssertEqual failed: ("# 한지 전체 내보내기\n") is not equal to ("# 갈피 전체 내보내기\n")`
- `BackupSchedulerTests` → `("["hanji-2026-08-31.sqlite"]") is not equal to ("["galpi-2026-08-31.sqlite"]")`

- [x] **Step 3: 소스를 고친다**

`Packages/Domain/Sources/Domain/MarkdownExporter.swift:16`:

```swift
        var out = "# 갈피 전체 내보내기\n"
```

`Packages/Data/Sources/Data/BackupScheduler.swift` — 17행 생성 경로와 23행 정리 필터 **양쪽 모두**:

```swift
        let target = backupsDir.appendingPathComponent("galpi-\(formatter.string(from: now)).sqlite")
```

```swift
            .filter { $0.lastPathComponent.hasPrefix("galpi-") && $0.pathExtension == "sqlite" }
```

> 두 곳을 함께 바꿔야 한다. 생성만 `galpi-`로 바꾸고 필터를 `hanji-`로 두면 **보관 개수 정리가 영구히 동작하지 않아** 백업이 무한정 쌓인다. 테스트 `keepsOnlyRecent`가 이걸 잡는다.

- [x] **Step 4: 테스트를 돌려 통과를 확인한다**

```bash
swift test --package-path Packages/Domain
swift test --package-path Packages/Data
```

Expected: 두 패키지 전체 스위트 PASS.

- [x] **Step 5: 커밋**

```bash
git add Packages/Domain Packages/Data
git commit -m "refactor: Domain·Data 계층 산출물 문자열 한지→갈피"
```

---

## Task 2: App 타깃·프로젝트 구성 리네임

`HanjiTheme` 심볼 하나가 10개 파일에 124회 등장한다. 기계적 치환이지만 **디렉터리 이동과 `project.yml` 갱신이 함께 가야** 빌드가 성립한다.

**Files:**
- Rename: `Hanji/` → `Galpi/` (디렉터리)
- Rename: `Galpi/HanjiApp.swift` → `Galpi/GalpiApp.swift`
- Rename: `Galpi/Theme/HanjiTheme.swift` → `Galpi/Theme/GalpiTheme.swift`
- Rename: `Galpi/Resources/Textures/HanjiGrain.png` → `Galpi/Resources/Textures/GalpiGrain.png`
- Modify: `Galpi/` 하위 전체 `.swift` (심볼·문자열)
- Modify: `project.yml`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: Task 1의 백업 파일명 규칙 `galpi-YYYY-MM-DD.sqlite`
- Produces: 타깃명 `Galpi`, 스킴 `Galpi`, 번들 ID `kr.hurdlers.Galpi`, 앱 지원 디렉터리명 `Galpi`, DB 파일명 `galpi.sqlite`. Task 3의 entitlements 경로와 Task 5의 서명 설정이 이 타깃명에 의존한다

- [x] **Step 1: 디렉터리와 파일을 옮긴다**

```bash
git mv Hanji Galpi
git mv Galpi/HanjiApp.swift Galpi/GalpiApp.swift
git mv Galpi/Theme/HanjiTheme.swift Galpi/Theme/GalpiTheme.swift
git mv Galpi/Resources/Textures/HanjiGrain.png Galpi/Resources/Textures/GalpiGrain.png
```

- [x] **Step 2: 심볼을 치환한다**

```bash
find Galpi -name "*.swift" -exec sed -i '' \
  -e 's/HanjiTheme/GalpiTheme/g' \
  -e 's/HanjiApp/GalpiApp/g' \
  -e 's/HanjiGrain/GalpiGrain/g' {} +
```

- [x] **Step 3: 사용자에게 보이는 한국어 문자열을 바꾼다**

`sed`로 일괄 치환하지 말 것 — 주석과 UI 문자열이 섞여 있어 문맥 확인이 필요하다. 아래 5곳을 직접 편집한다:

`Galpi/GalpiApp.swift:62` (메뉴바 아이콘 접근성 레이블):
```swift
                                 accessibilityDescription: "갈피")
```

`Galpi/GalpiApp.swift:129` (우클릭 메뉴):
```swift
        menu.addItem(withTitle: "갈피 종료",
```

`Galpi/GalpiApp.swift:141` (설정 창 제목):
```swift
            window.title = "갈피 설정"
```

`Galpi/Timeline/HeaderView.swift:19` (헤더 워드마크):
```swift
            Text("갈피")
```

`Galpi/GalpiApp.swift` 내보내기 기본 파일명 (157행 부근):
```swift
                panel.nameFieldStringValue = "galpi-export.md"
```

주석 2곳(`Galpi/Theme/GalpiTheme.swift:109`, `Galpi/Timeline/HeaderView.swift:5`)의 `"한지"` 워드마크 언급도 `"갈피"`로 고친다.

- [x] **Step 4: DB 경로를 바꾼다**

`Galpi/GalpiApp.swift:37-41`:

```swift
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Galpi")
        do {
            repo = try GRDBNoteRepository(databaseURL: appSupport.appendingPathComponent("galpi.sqlite"))
```

> `.applicationSupportDirectory`는 샌드박스가 켜지면 자동으로 컨테이너 안으로 리다이렉트된다. Task 3에서 코드를 또 고칠 필요가 없다.

- [x] **Step 5: `project.yml`을 갱신한다**

```yaml
name: Galpi
options:
  bundleIdPrefix: kr.hurdlers
  deploymentTarget:
    macOS: "14.0"
packages:
  Domain:
    path: Packages/Domain
  Data:
    path: Packages/Data
  PanelKit:
    path: Packages/PanelKit
  KeyboardShortcuts:
    url: https://github.com/sindresorhus/KeyboardShortcuts
    from: 2.0.0
targets:
  Galpi:
    type: application
    platform: macOS
    sources:
      - path: Galpi
    dependencies:
      - package: Domain
      - package: Data
      - package: PanelKit
      - package: KeyboardShortcuts
    info:
      path: Galpi/Info.plist
      properties:
        LSUIElement: true
        CFBundleDisplayName: 갈피
        NSHumanReadableCopyright: ""
        ATSApplicationFontsPath: .
    settings:
      base:
        SWIFT_VERSION: "5.10"
        CODE_SIGN_IDENTITY: "-"
        ENABLE_HARDENED_RUNTIME: false
```

> `CODE_SIGN_IDENTITY`와 `ENABLE_HARDENED_RUNTIME`은 이 태스크에서 **그대로 둔다.** Task 5에서 한꺼번에 바꿔야 로컬 빌드가 중간에 깨지지 않는다.

- [x] **Step 6: `.gitignore`를 갱신한다**

`Hanji/Info.plist` 줄을 `Galpi/Info.plist`로 바꾼다.

- [x] **Step 7: 빌드하고 실행해 확인한다**

```bash
rm -rf Hanji.xcodeproj build
xcodegen generate
xcodebuild -project Galpi.xcodeproj -scheme Galpi -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/Galpi.app
```

Expected: 빌드 성공. 메뉴바에 아이콘이 뜨고, ⌥Space로 패널이 열리고, **헤더 워드마크가 "갈피"로 보인다.** 우클릭 메뉴에 "갈피 종료"가 있다.

> 이 시점에는 앱이 빈 DB로 시작한다 (`Galpi/galpi.sqlite`가 새로 생성됨). 기존 메모는 Task 4에서 옮긴다. 놀라지 말 것.

- [x] **Step 8: 남은 참조가 없는지 검증한다**

```bash
grep -rn "Hanji\|hanji" --include="*.swift" --include="*.yml" --include="*.gitignore" Galpi/ Packages/ project.yml .gitignore | grep -v build/ | grep -v "\.build/"
```

Expected: 출력 없음. 무언가 나오면 문맥을 보고 고친 뒤 Step 7을 다시 돌린다.

- [x] **Step 9: 커밋**

```bash
git add -A
git commit -m "refactor: 앱 타깃·번들ID·경로 Hanji→Galpi 리브랜딩"
```

---

## Task 3: App Sandbox 도입

Mac App Store의 **유일한 하드 블로커**다. `com.apple.security.app-sandbox` 없이는 제출 자체가 거부된다.

이 앱이 쓰는 민감 API는 전부 이미 샌드박스 호환 방식이라 **entitlement 추가 외에 코드 수정이 없어야 정상**이다. 그 전제를 수동 QA로 검증하는 것이 이 태스크의 본체다.

**Files:**
- Create: `Galpi/Galpi.entitlements`
- Modify: `project.yml`
- Modify: `docs/qa-checklist.md`

**Interfaces:**
- Consumes: Task 2의 타깃명 `Galpi`, 번들 ID `kr.hurdlers.Galpi`
- Produces: 샌드박스 컨테이너 경로 `~/Library/Containers/kr.hurdlers.Galpi/Data/Library/Application Support/Galpi/`. Task 4의 데이터 이관이 이 경로에 의존한다

- [x] **Step 1: entitlements 파일을 만든다**

`Galpi/Galpi.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.files.user-selected.read-write</key>
	<true/>
</dict>
</plist>
```

> `files.user-selected.read-write`는 "전체 내보내기"의 `NSSavePanel`을 위한 것이다. Powerbox가 사용자가 고른 경로만 열어주므로 임의 파일 접근권이 아니며, 리뷰에서 문제되지 않는다.
>
> **넣지 말아야 할 것:** `com.apple.security.network.client` — 이 앱은 네트워크를 쓰지 않는다. 습관적으로 넣으면 개인정보 라벨 심사에서 불필요한 질문을 받는다.

- [x] **Step 2: `project.yml`에 entitlements를 연결한다**

`targets.Galpi.settings.base`에 한 줄 추가:

```yaml
    settings:
      base:
        SWIFT_VERSION: "5.10"
        CODE_SIGN_IDENTITY: "-"
        ENABLE_HARDENED_RUNTIME: false
        CODE_SIGN_ENTITLEMENTS: Galpi/Galpi.entitlements
```

- [x] **Step 3: 빌드하고 샌드박스가 실제로 켜졌는지 확인한다**

```bash
xcodegen generate
xcodebuild -project Galpi.xcodeproj -scheme Galpi -configuration Debug -derivedDataPath build build
codesign -d --entitlements - build/Build/Products/Debug/Galpi.app
```

Expected: 출력에 `com.apple.security.app-sandbox` → `true`가 보인다.

- [x] **Step 4: 컨테이너가 생성되는지 확인한다**

```bash
open build/Build/Products/Debug/Galpi.app
sleep 3
ls -la ~/Library/Containers/kr.hurdlers.Galpi/Data/Library/Application\ Support/Galpi/
```

Expected: `galpi.sqlite`와 `Backups/`가 컨테이너 **안에** 생성되어 있다. `~/Library/Application Support/Galpi/`에는 아무것도 안 생긴다.

- [x] **Step 5: 샌드박스에서 깨지기 쉬운 4가지를 수동 검증한다**

아래를 직접 눌러보고 전부 통과해야 한다. 하나라도 실패하면 원인을 규명하기 전까지 다음 태스크로 넘어가지 않는다:

1. **전역 단축키** — ⌥Space로 패널이 열린다 (KeyboardShortcuts는 Carbon `RegisterEventHotKey` 기반이라 손쉬운 접근 권한 없이 동작해야 정상)
2. **직전 앱 포커스 복귀** — Safari를 띄운 상태에서 ⌥Space → 메모 입력 → Esc → **Safari로 포커스가 돌아간다.** (`NSWorkspace.frontmostApplication` + `activate()`가 샌드박스에서 제한될 수 있는 유일한 지점 — 여기가 이 태스크의 진짜 리스크다)
3. **전체 내보내기** — 우클릭 메뉴 → "전체 내보내기…" → 바탕화면에 저장 → **파일이 실제로 생성되고 내용이 올바르다**
4. **로그인 시 자동 시작** — 설정에서 토글 켜고 `SMAppService.mainApp.status`가 `.enabled`가 되는지 확인. 껐다 켜기도 해본다

- [x] **Step 6: QA 체크리스트에 샌드박스 항목을 추가한다**

`docs/qa-checklist.md`의 "## 데이터" 섹션 앞에 새 섹션을 넣는다:

```markdown
## 샌드박스 (App Store 빌드 필수)
- [ ] `codesign -d --entitlements -` 출력에 app-sandbox = true
- [ ] 데이터가 ~/Library/Containers/kr.hurdlers.Galpi/ 안에 생성된다
- [ ] ⌥Space 전역 단축키가 손쉬운 접근 권한 없이 동작한다
- [ ] Esc로 닫으면 직전 앱(Safari 등)으로 포커스가 복귀한다
- [ ] 전체 내보내기가 NSSavePanel로 실제 파일을 쓴다
- [ ] 로그인 시 자동 시작 토글이 켜지고 꺼진다
```

- [ ] **Step 7: 커밋**

```bash
git add Galpi/Galpi.entitlements project.yml docs/qa-checklist.md
git commit -m "feat: App Sandbox entitlement 도입 — Mac App Store 요구사항"
```

---

## Task 4: 개인 데이터 컨테이너 이관 (일회성 수동 작업)

**신규 사용자와 무관하다.** App Store로 받는 사람은 빈 상태로 시작한다. 이건 순전히 제작자 본인이 지금까지 쌓은 메모를 살리기 위한 작업이다.

샌드박스 앱은 컨테이너 밖의 `~/Library/Application Support/Hanji/`를 **읽을 수 없으므로** 코드로 자동 이관하는 것은 불가능하다. 터미널에서 한 번 옮긴다.

**Files:** 없음 (코드 변경 없음)

- [x] **Step 1: 앱을 종료한다**

WAL이 열린 채로 복사하면 데이터가 유실될 수 있다. 메뉴바 → "갈피 종료"로 확실히 끈다.

```bash
pgrep -x Galpi || echo "종료됨 — 진행 가능"
```

Expected: `종료됨 — 진행 가능`

- [x] **Step 2: WAL을 본체에 합친다**

```bash
sqlite3 ~/Library/Application\ Support/Hanji/hanji.sqlite "PRAGMA wal_checkpoint(TRUNCATE);"
```

Expected: `0|N|N` 형태의 출력. WAL 파일 크기가 0에 가까워진다.

- [x] **Step 3: 컨테이너로 복사한다 (이동 아님)**

```bash
DEST=~/Library/Containers/kr.hurdlers.Galpi/Data/Library/Application\ Support/Galpi
mkdir -p "$DEST"
cp ~/Library/Application\ Support/Hanji/hanji.sqlite "$DEST/galpi.sqlite"
ls -la "$DEST"
```

Expected: `galpi.sqlite`가 원본과 같은 크기로 존재한다.

> **복사이지 이동이 아니다.** 원본 `~/Library/Application Support/Hanji/`는 롤백 안전망으로 남겨둔다. 몇 주 쓰고 문제없으면 그때 지운다.

- [x] **Step 4: 앱을 켜서 메모가 살아있는지 확인한다**

```bash
open build/Build/Products/Debug/Galpi.app
```

Expected: 기존 메모가 타임라인에 전부 보인다. 검색(초성 포함)과 폴더 칩도 정상 동작한다.

> 안 보이면 Step 3의 목적지 경로 오타를 먼저 의심한다. 원본은 그대로 있으니 복구 가능하다.

---

## Task 5: 코드사인 + App Store 아카이브 검증

**Task 0의 Apple Developer Program 가입이 완료되어야 시작할 수 있다.**

**Files:**
- Modify: `project.yml`

**Interfaces:**
- Consumes: Task 3의 entitlements, Task 2의 번들 ID
- Produces: App Store Connect 업로드 가능한 `.pkg` 아카이브

- [ ] **Step 1: 팀 ID를 확인한다**

```bash
security find-identity -v -p codesigning
```

Expected: `Apple Development: ...` 또는 `Apple Distribution: ...` 항목과 괄호 안 10자리 팀 ID가 보인다. 안 보이면 Xcode → Settings → Accounts에서 Apple ID를 추가하고 인증서를 내려받는다.

- [ ] **Step 2: `project.yml`의 서명 설정을 바꾼다**

`YOUR_TEAM_ID`를 Step 1에서 확인한 실제 값으로 채운다:

```yaml
    settings:
      base:
        SWIFT_VERSION: "5.10"
        CODE_SIGN_ENTITLEMENTS: Galpi/Galpi.entitlements
        CODE_SIGN_STYLE: Automatic
        DEVELOPMENT_TEAM: YOUR_TEAM_ID
        ENABLE_HARDENED_RUNTIME: true
```

`CODE_SIGN_IDENTITY: "-"` 줄은 **삭제한다.** 자동 서명이 상황에 맞는 인증서를 고르게 둔다.

버전은 빌드 설정이 아니라 `info.properties`에 넣는다. `targets.Galpi.info.properties`에 두 줄 추가:

```yaml
        CFBundleShortVersionString: "1.0"
        CFBundleVersion: "1"
```

> `MARKETING_VERSION`·`CURRENT_PROJECT_VERSION` 빌드 설정을 쓰면 안 된다. XcodeGen이 `Info.plist`에 리터럴 `1.0`/`1`을 먼저 써넣기 때문에 빌드 설정이 무시되고, 업데이트를 낼 때 버전을 올렸는데도 반영되지 않는 조용한 버그가 된다. App Store는 같은 `CFBundleVersion` 재업로드를 거부하므로 여기서 시간을 크게 날릴 수 있다.

> Hardened Runtime은 App Store 제출의 필수 요건은 아니지만(샌드박스가 그 역할), 켜두면 나중에 웹 직접 배포(Developer ID + 공증)로 확장할 때 그대로 쓸 수 있다. 이 앱은 JIT·동적 코드 로딩을 안 하므로 예외 entitlement 없이 켜져야 정상이다.

- [ ] **Step 3: 릴리스 아카이브를 만든다**

```bash
xcodegen generate
xcodebuild -project Galpi.xcodeproj -scheme Galpi -configuration Release \
  -archivePath build/Galpi.xcarchive archive
```

Expected: `ARCHIVE SUCCEEDED`. 실패하면 대개 프로비저닝 프로파일 문제이므로 Xcode로 프로젝트를 열어 Signing & Capabilities 탭의 경고를 읽는다.

- [ ] **Step 4: 아카이브의 서명과 entitlements를 검증한다**

```bash
codesign -dv --entitlements - build/Galpi.xcarchive/Products/Applications/Galpi.app 2>&1 | head -30
```

Expected: `Authority=Apple Distribution: ...`, entitlements에 `app-sandbox = true`, `Identifier=kr.hurdlers.Galpi`.

- [ ] **Step 5: 커밋**

```bash
git add project.yml
git commit -m "chore: App Store 배포용 코드사인·Hardened Runtime 설정"
```

> `DEVELOPMENT_TEAM`이 공개 저장소에 들어가는 게 꺼려지면 `project.yml`에서 빼고 `xcodebuild` 인자로 넘기는 방식으로 바꾼다. 팀 ID 자체는 비밀 정보가 아니라 앱 번들에서 누구나 읽을 수 있으므로, 개인 저장소라면 그냥 둬도 무방하다.

---

## Task 6: 앱 아이콘 에셋

스펙 §11의 미해결 항목. **아이콘 없이는 App Store 제출이 불가능하다.**

현재 프로젝트에는 `.xcassets`가 아예 없어서 에셋 카탈로그부터 만들어야 한다.

**Files:**
- Create: `Galpi/Resources/Assets.xcassets/Contents.json`
- Create: `Galpi/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `Galpi/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png` 외 9개 PNG
- Modify: `project.yml`

**Interfaces:**
- Consumes: Task 2의 타깃 구성
- Produces: `AppIcon` 에셋 이름 — `project.yml`의 `ASSETCATALOG_COMPILER_APPICON_NAME`이 참조한다

- [ ] **Step 1: 1024×1024 원본 아이콘을 만든다**

디자인 방향 — 브랜드가 한지에서 갈피로 바뀌었으므로 붓 모티프보다 **책갈피**가 맞다. 스펙 §8의 색을 그대로 쓴다: 한지 미색 바탕(`#F5F1E8` 계열), 먹빛 획, 쪽빛(`#2E5A88` 계열) 갈피 끈 하나. macOS 26 아이콘 가이드라인상 둥근 사각형 안에 여백을 넉넉히 둔다.

원본을 `Galpi/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png`로 저장한다.

> 이 단계는 디자인 작업이라 코드로 대체할 수 없다. 직접 그리거나 디자이너에게 맡긴다. 임시로 진행하려면 단색 바탕에 갈피 끈만 있는 단순한 도형으로 시작해도 제출은 통과한다 — 다만 스토어 목록에서 첫인상을 결정하는 요소이므로 런칭 전에는 제대로 만든다.

- [ ] **Step 2: 나머지 크기를 생성한다**

```bash
cd Galpi/Resources/Assets.xcassets/AppIcon.appiconset
for s in 16 32 64 128 256 512; do
  sips -z $s $s icon_1024.png --out icon_${s}.png
done
sips -z 1024 1024 icon_1024.png --out icon_512@2x.png
sips -z 512 512 icon_1024.png --out icon_256@2x.png
sips -z 256 256 icon_1024.png --out icon_128@2x.png
sips -z 64 64 icon_1024.png --out icon_32@2x.png
sips -z 32 32 icon_1024.png --out icon_16@2x.png
cd -
```

- [ ] **Step 3: 에셋 카탈로그 메타데이터를 쓴다**

`Galpi/Resources/Assets.xcassets/Contents.json`:

```json
{
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`Galpi/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images" : [
    { "filename" : "icon_16.png",     "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16@2x.png",  "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32.png",     "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32@2x.png",  "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128.png",    "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256.png",    "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512.png",    "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 4: `project.yml`에 에셋 카탈로그를 연결한다**

`targets.Galpi.settings.base`에 추가:

```yaml
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
```

- [ ] **Step 5: 빌드해서 아이콘이 붙었는지 확인한다**

```bash
xcodegen generate
xcodebuild -project Galpi.xcodeproj -scheme Galpi -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/
```

Expected: Finder에서 `Galpi.app`에 새 아이콘이 보인다. (`LSUIElement`라 Dock에는 안 뜨는 게 정상이다.)

- [ ] **Step 6: 커밋**

```bash
git add Galpi/Resources/Assets.xcassets project.yml
git commit -m "feat: 앱 아이콘 에셋 카탈로그 추가"
```

---

## Task 7: 스펙·문서 갱신

**Files:**
- Modify: `docs/superpowers/specs/2026-08-31-hanji-design.md`
- Modify: `docs/qa-checklist.md`
- Rename: 스펙 파일명은 **그대로 둔다** (날짜 기반 이력이므로 소급 변경하지 않는다)

- [x] **Step 1: 스펙에 v1.4 리브랜딩 항목을 추가한다**

`## 3. 확정 정책` 표에 행을 추가한다:

```markdown
| 제품명 (v1.4) | **갈피 (Galpi)** — 2026-09-01 변경. 구 Hanji(한지). 사유: hanji.kr 및 .kr 계열 전 선점, 일반명사라 상표 식별력 부족, Play스토어 동명 앱 존재. 도메인 galpi.com / galpi.app |
| 배포 (v1.4) | Mac App Store **무료** 배포. App Sandbox 필수, 번들 ID `kr.hurdlers.Galpi` 영구 고정 |
| 저장 위치 (v1.4) | 샌드박스 컨테이너 `~/Library/Containers/kr.hurdlers.Galpi/Data/Library/Application Support/Galpi/galpi.sqlite` |
```

§3의 기존 "저장 위치" 행과 §11의 "앱 아이콘 디자인", "앱 이름 표기" 항목도 갱신·해소 처리한다.

- [x] **Step 2: 커밋**

```bash
git add docs/
git commit -m "docs: 스펙 v1.4 — 갈피 리브랜딩 및 App Store 배포 정책"
```

---

## 제출 전 체크리스트 (코드 아님)

Task 1~7 완료 후, App Store Connect에서 처리한다.

- [ ] **개인정보 라벨** — 전 항목 "데이터를 수집하지 않음". 네트워크 코드가 없으므로 사실 그대로다
- [ ] **개인정보처리방침 URL** — `galpi.com/privacy` (Task 0에서 게시)
- [ ] **스크린샷** — Mac용 1280×800 이상. 최소 1장, 권장 4~5장. 한지 라이트/먹 다크 양쪽을 보여준다. **초성 검색 장면을 반드시 포함** — 이게 유일한 차별점이다
- [ ] **앱 설명** — 첫 두 줄이 목록에서 잘리지 않고 보이는 전부다. "초성으로 찾는 맥 메모장" 같은 훅을 맨 앞에 둔다
- [ ] **키워드** — 메모, 초성검색, 한글, 스크래치패드, 마크다운, 메뉴바
- [ ] **카테고리** — 생산성
- [ ] **연령 등급** — 4+
- [ ] **판매 지역** — 전 지역 허용. UI가 한국어라 실질 사용자는 한국이지만, 막을 이유가 없다
- [ ] **저작권 표기** — `NSHumanReadableCopyright`가 현재 빈 문자열이다. `© 2026 <이름>` 형태로 채운다
- [ ] **폰트 라이선스 고지** — OFL은 라이선스 사본 동봉을 요구한다. `Resources/Fonts/LICENSE.txt`가 번들에 포함되는지 확인하고, 설정 창에도 "오픈소스 라이선스" 항목을 두면 더 안전하다
- [ ] **심사 메모** — 리뷰어에게 남긴다: "메뉴바 상주 앱입니다(LSUIElement). Dock 아이콘이 없으며, 메뉴바의 아이콘을 클릭하거나 ⌥Space를 눌러 실행합니다." **이 메모가 없으면 '앱이 실행되지 않는다'는 사유로 반려될 수 있다** — 메뉴바 앱의 가장 흔한 반려 원인이다

---

## 이번 범위에서 제외 — 그리고 그 다음 (2026-09-01 로드맵 확정)

이 계획서는 **1단계**다. 유료화를 아예 안 하기로 한 게 아니라, **수요를 싸게 검증한 뒤에 투자**하기로 순서를 정한 것이다. Task 1~7은 유료 버전에도 전부 그대로 필요하므로 버려지는 작업이 없다.

```
1단계 (이 계획서, 2주)   무료 Mac 런칭 → 수요 검증
2단계 (4~6주)            반응 측정 — 다운로드·리뷰·커뮤니티
3단계 (조건부)           iCloud 동기화 + iOS 앱 + 영문 로케일
4단계                    무료 유지 + "갈피 Plus" $5 IAP로 동기화·iOS 잠금 해제
```

**4단계를 $5 선결제가 아니라 IAP로 하는 이유:** 무료로 받아 써보고 결제하는 편이 전환율이 높고, 이미 무료로 받은 사용자를 잃지 않으며, [Small Business Program 15% 수수료](https://developer.apple.com/app-store/small-business-program/)가 IAP에도 동일하게 적용된다(신규 개발자 즉시 자격). $5 IAP 실수령 약 $4.25.

### 3단계 착수 시 이미 내려둔 기술 결정

**동기화는 [SQLiteData](https://github.com/pointfreeco/sqlite-data)(Point-Free, v1.0.0, MIT)로 간다.** GRDB 위에 얹히는 CloudKit 동기화라 현재 Domain·Data 계층을 거의 그대로 살릴 수 있다. 검토했다가 탈락시킨 대안과 사유:

- **Harmony** — GRDB 전용 CloudKit 동기화지만 **외래키를 지원하지 않는다.** 현 스키마의 `note.folder_id → folder (SET NULL)`와 정면 충돌하므로 스키마를 바꾸지 않는 한 쓸 수 없다
- **NSPersistentCloudKitContainer** — Core Data가 전제라 GRDB를 폐기해야 하고, 자모·초성 LIKE 검색을 재설계해야 한다. 게다가 iCloud 계정을 사용할 수 없다고 판단하면 로컬 레코드를 지우는 성향이 있어 메모앱에는 위험하다
- **CKSyncEngine 직접 구현** — 제어권은 최대지만 손이 가장 많이 간다. SQLiteData가 막힐 때의 대안으로만 남겨둔다

**현 스키마는 이미 동기화 친화적이다** — `Note.id`, `Folder.id`가 `UUID`이고 유니크 제약에 의존하지 않는다(CloudKit은 유니크 제약을 지원하지 않는다). **1단계 작업 중 이 성질을 깨지 말 것.** 정수 auto-increment PK나 유니크 인덱스를 새로 도입하면 3단계에서 마이그레이션 비용이 생긴다.

### iOS 앱의 실제 비용 (3단계 최대 항목)

계층별 재사용률 — `Domain/` 100%, `Data/` 약 80%, SwiftUI 뷰 약 50%, `PanelKit/` **0%**(NSPanel 엣지 패널은 iOS에 개념이 없다), `ComposerTextView` **0%**(NSTextView → UITextView 전면 재작성).

마지막 항목이 진짜 비용이다. **이 앱에서 가장 비싸게 얻은 코드가 한글 IME 처리**이고(QA r3·r4·r5 라운드에서 조합 중 전송·마커 텍스트·스마트 치환으로 반복 실패), 그 경험을 UIKit에서 처음부터 다시 쌓아야 한다. 풀타임 4~8주로 잡는다.

### 그대로 제외

- **영문 로케일** — 3단계에 포함. 다만 **초성 검색은 한국어에서만 의미가 있다**는 점을 기억할 것. 영어권 포지셔닝은 "SideNotes($19.99)의 기능을 1/4 값에"가 되어야지, 초성 검색이 주장이 될 수 없다
- **핫 엣지 트리거** — 스펙에서 이미 MVP 제외
