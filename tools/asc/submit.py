#!/usr/bin/env python3
"""App Store Connect 제출 자동화 — 외부 의존성 없음 (python3 + openssl).

환경변수:
  ASC_ISSUER_ID   App Store Connect API Issuer ID (UUID)
  ASC_KEY_ID      키 ID (예: 9THV32YVVS)
  ASC_KEY_PATH    .p8 경로 (기본 ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8)
  ASC_BUNDLE_ID   기본 kr.hurdlers.Hanjjok
  ASC_CONTACT_*   심사 연락처: FIRST, LAST, PHONE, EMAIL

사용:
  submit.py status              앱·버전·빌드·로컬라이즈 현황
  submit.py metadata            카테고리·연령등급·부제·개인정보 URL·설명·키워드·프로모션·지원 URL
  submit.py screenshots [dir]   docs/screenshots/*.png → APP_DESKTOP 세트로 교체 업로드
  submit.py price               무료(가격 스케줄 base territory KOR)
  submit.py build               처리 완료된 최신 빌드를 버전에 연결 + 암호화 면제 표시
  submit.py review              심사 연락처·메모
  submit.py submit              심사 제출
  submit.py all                 위 전부 순서대로 (submit 제외)
"""
import base64, hashlib, json, os, subprocess, sys, time, urllib.request, urllib.error, glob

API = "https://api.appstoreconnect.apple.com"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BUNDLE = os.environ.get("ASC_BUNDLE_ID", "kr.hurdlers.Hanjjok")
LOCALE = "ko"

# ---------- 문안 (docs/appstore-listing.md 와 동일하게 유지) ----------
SUBTITLE = "화면 한쪽에 종이 한 장, 메뉴바 메모"
PRIVACY_URL = "https://github.com/dbwnsgur741/hanjjok/blob/main/docs/privacy.md"
SUPPORT_URL = "https://github.com/dbwnsgur741/hanjjok/issues"
PROMO = "ㅅㅇㄷ만 쳐도 찾아지는 메모장. 메뉴바에서 Option+Space 한 번이면 화면 한쪽에 종이 한 장이 나옵니다. 계정도, 서버도, 동기화도 없이 전부 내 Mac 안에만."
KEYWORDS = "메모,초성검색,한글,메모장,스크래치패드,마크다운,메뉴바,빠른메모,체크리스트,노트,한지"
DESCRIPTION = """초성으로 찾는 맥 메모장. ㅅㅇㄷ를 치면 "사이드노트"가 나오고, 사이ㄷ처럼 아직 조합 중인 글자로도 결과가 끊기지 않습니다.

카카오톡 '나와의 채팅'에 메모하던 습관을 Mac 메뉴바로 옮겼습니다. Option+Space를 누르면 화면 한쪽에서 종이 한 장이 미끄러져 나오고, 적고, Esc로 닫으면 하던 일로 돌아갑니다. 생각에서 기록까지 1초.

한쪽이 하는 것
• 초성·부분 검색 — 한글 조합 중에도 결과가 유지됩니다
• 시간순 타임라인 — 폴더 계층 없이 위에서 아래로 쌓입니다
• #태그로 분류, 1단계 폴더로 정리
• 가벼운 마크다운 — 제목, 굵게, 인용, 불릿, 체크리스트
• 체크리스트는 카드에서 바로 완료 토글
• 라이트는 한지, 다크는 먹 — 시스템 설정을 따릅니다
• 본문 글꼴 마루부리 / Pretendard 전환
• 전체 메모를 마크다운 파일로 내보내기 — 락인 없음

한쪽이 안 하는 것
• 계정, 서버, 동기화, 광고, 분석. 네트워크에 연결하지 않습니다.
• 모든 메모는 이 Mac에만 있습니다.

메뉴바 앱입니다. Dock에 아이콘이 없습니다. 메뉴바의 아이콘을 누르거나 Option+Space(설정에서 변경 가능)로 엽니다. 로그인 시 자동 실행을 켤 수 있습니다.

macOS 14 Sonoma 이상."""
REVIEW_NOTES = """이 앱은 메뉴바 상주 앱입니다 (LSUIElement = true). Dock에 아이콘이 나타나지 않는 것이 정상입니다.

실행 방법:
1. 앱을 열면 메뉴바 오른쪽에 아이콘이 나타납니다.
2. 아이콘을 클릭하거나 ⌥Space(Option+Space)를 누르면 화면 오른쪽 가장자리에서 메모 패널이 나타납니다.
3. 패널에 텍스트를 입력하고 Enter로 저장합니다. Esc로 패널을 닫습니다.
4. 메뉴바 아이콘을 우클릭하면 설정·전체 내보내기·종료 메뉴가 있습니다.

네트워크 통신이 없으며 모든 데이터는 로컬 샌드박스 컨테이너에 저장됩니다."""

# ---------- JWT (ES256, openssl) ----------
def b64u(b): return base64.urlsafe_b64encode(b).rstrip(b"=").decode()
def der_to_raw(sig):
    assert sig[0] == 0x30; i = 2
    def read_int():
        nonlocal i
        assert sig[i] == 0x02; n = sig[i+1]; v = sig[i+2:i+2+n]; i += 2 + n
        return v.lstrip(b"\x00").rjust(32, b"\x00")
    return read_int() + read_int()
_tok = {"jwt": None, "exp": 0}
def token():
    if _tok["jwt"] and time.time() < _tok["exp"] - 60: return _tok["jwt"]
    iss, kid = os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_ID"]
    key = os.environ.get("ASC_KEY_PATH", os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{kid}.p8"))
    now = int(time.time()); exp = now + 19 * 60
    h = b64u(json.dumps({"alg": "ES256", "kid": kid, "typ": "JWT"}).encode())
    p = b64u(json.dumps({"iss": iss, "iat": now, "exp": exp, "aud": "appstoreconnect-v1"}).encode())
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key, "-binary"], input=f"{h}.{p}".encode(), capture_output=True, check=True).stdout
    _tok["jwt"], _tok["exp"] = f"{h}.{p}.{b64u(der_to_raw(der))}", exp
    return _tok["jwt"]

def api(method, path, body=None, raw=False, headers=None):
    url = path if path.startswith("http") else API + path
    data = None if body is None else (body if raw else json.dumps(body).encode())
    req = urllib.request.Request(url, data=data, method=method)
    if not raw: req.add_header("Content-Type", "application/json")
    if url.startswith(API): req.add_header("Authorization", f"Bearer {token()}")  # presigned S3 URL엔 붙이면 400
    for k, v in (headers or {}).items(): req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            txt = r.read()
            return json.loads(txt) if txt and not raw else {}
    except urllib.error.HTTPError as e:
        err = e.read().decode(errors="replace")
        raise SystemExit(f"HTTP {e.code} {method} {path}\n{err[:1500]}")

def rel(t, i): return {"data": {"type": t, "id": i}}
def log(*a): print(*a, flush=True)

# ---------- 조회 ----------
def app():
    r = api("GET", f"/v1/apps?filter[bundleId]={BUNDLE}")
    if not r["data"]: raise SystemExit(f"앱 레코드 없음: {BUNDLE}")
    return r["data"][0]
def version(app_id, create=False):
    r = api("GET", f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=MAC_OS&limit=5")
    live = [v for v in r["data"] if v["attributes"]["appStoreState"] in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "WAITING_FOR_REVIEW", "IN_REVIEW")]
    if live: return live[0]
    if not create: return r["data"][0] if r["data"] else None
    return api("POST", "/v1/appStoreVersions", {"data": {"type": "appStoreVersions", "attributes": {"platform": "MAC_OS", "versionString": "1.0"}, "relationships": {"app": rel("apps", app_id)}}})["data"]
def version_loc(vid):
    r = api("GET", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations")
    for l in r["data"]:
        if l["attributes"]["locale"] == LOCALE: return l
    return api("POST", "/v1/appStoreVersionLocalizations", {"data": {"type": "appStoreVersionLocalizations", "attributes": {"locale": LOCALE}, "relationships": {"appStoreVersion": rel("appStoreVersions", vid)}}})["data"]
def app_info(app_id):
    r = api("GET", f"/v1/apps/{app_id}/appInfos")
    pref = [i for i in r["data"] if i["attributes"].get("appStoreState") == "PREPARE_FOR_SUBMISSION"]
    return (pref or r["data"])[0]
def app_info_loc(info_id):
    r = api("GET", f"/v1/appInfos/{info_id}/appInfoLocalizations")
    for l in r["data"]:
        if l["attributes"]["locale"] == LOCALE: return l
    raise SystemExit("appInfoLocalization(ko) 없음 — App Store Connect에서 기본 언어를 한국어로 만들었는지 확인")
def latest_build(app_id):
    r = api("GET", f"/v1/builds?filter[app]={app_id}&sort=-uploadedDate&limit=5")
    return r["data"]

# ---------- 단계 ----------
def cmd_status():
    a = app(); log(f"앱: {a['attributes']['name']} ({a['id']}) sku={a['attributes']['sku']}")
    v = version(a["id"]); log(f"버전: {v['attributes']['versionString'] if v else None} state={v['attributes']['appStoreState'] if v else None}")
    il = app_info_loc(app_info(a["id"])["id"]); at = il["attributes"]
    log(f"appInfo(ko): name={at.get('name')!r} subtitle={at.get('subtitle')!r} privacy={at.get('privacyPolicyUrl')!r}")
    if v:
        vl = version_loc(v["id"]); va = vl["attributes"]
        log(f"version(ko): desc={len(va.get('description') or '')}자 keywords={va.get('keywords')!r} support={va.get('supportUrl')!r}")
        sets = api("GET", f"/v1/appStoreVersionLocalizations/{vl['id']}/appScreenshotSets")["data"]
        for s in sets:
            n = len(api("GET", f"/v1/appScreenshotSets/{s['id']}/appScreenshots")["data"])
            log(f"스크린샷 세트: {s['attributes']['screenshotDisplayType']} {n}장")
        b = api("GET", f"/v1/appStoreVersions/{v['id']}/build").get("data")
        log(f"연결된 빌드: {b['attributes']['version'] if b else None}")
    for b in latest_build(a["id"]):
        log(f"빌드 {b['attributes']['version']} state={b['attributes']['processingState']} uploaded={b['attributes']['uploadedDate']} encryption={b['attributes'].get('usesNonExemptEncryption')}")

_UNUSED_AGE_FULL = {k: "NONE" for k in ["alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated", "medicalOrTreatmentInformation",
    "profanityOrCrudeHumor", "sexualContentGraphicAndNudity", "sexualContentOrNudity", "horrorOrFearThemes", "matureOrSuggestiveThemes",
    "violenceCartoonOrFantasy", "violenceRealisticProlongedGraphicOrSadistic", "violenceRealistic"]}
_UNUSED_AGE_FULL.update({"gambling": False, "unrestrictedWebAccess": False, "lootBox": False})
AGE_2025 = {"advertising": False, "ageAssurance": False, "healthOrWellnessTopics": False, "messagingAndChat": False, "parentalControls": False, "userGeneratedContent": False}

def cmd_metadata():
    a = app(); info = app_info(a["id"])
    api("PATCH", f"/v1/appInfos/{info['id']}", {"data": {"type": "appInfos", "id": info["id"], "relationships": {"primaryCategory": rel("appCategories", "PRODUCTIVITY")}}})
    log("카테고리: 생산성")
    ar = api("GET", f"/v1/appInfos/{info['id']}/ageRatingDeclaration")["data"]
    BOOL_KEYS = {"gambling", "unrestrictedWebAccess", "lootBox", "advertising", "ageAssurance", "healthOrWellnessTopics",
                 "messagingAndChat", "parentalControls", "userGeneratedContent", "seventeenPlus"}
    attrs = {}
    for k, v in ar["attributes"].items():
        if k == "kidsAgeBand": attrs[k] = None
        elif k in BOOL_KEYS or isinstance(v, bool): attrs[k] = False
        else: attrs[k] = "NONE"
    import re as _re
    for attempt in range(6):  # 에러 응답을 읽어 타입 교정·읽기전용 키 제거하며 재시도
        try:
            api("PATCH", f"/v1/ageRatingDeclarations/{ar['id']}", {"data": {"type": "ageRatingDeclarations", "id": ar["id"], "attributes": attrs}})
            log(f"연령 등급: {len(attrs)}개 항목 없음/false (4+)"); break
        except SystemExit as e:
            msg = str(e); changed = False
            for m in _re.finditer(r"Expected a BOOLEAN[^\n]*?attribute '([A-Za-z]+)'|attribute '([A-Za-z]+)'\. Expected a BOOLEAN", msg):
                k = m.group(1) or m.group(2); attrs[k] = False; changed = True
            for m in _re.finditer(r'"pointer" : "/data/attributes/([A-Za-z]+)"', msg):
                k = m.group(1)
                if k in attrs and attrs[k] == "NONE" and ("BOOLEAN" in msg): attrs[k] = False; changed = True
                elif k in attrs and ("not allowed" in msg.lower() or "read-only" in msg.lower() or "unknown" in msg.lower()): attrs.pop(k, None); changed = True
            if not changed: log("⚠️ 연령 등급 API 실패 — UI에서 설정 필요\n", msg[:1500]); break
    il = app_info_loc(info["id"])
    api("PATCH", f"/v1/appInfoLocalizations/{il['id']}", {"data": {"type": "appInfoLocalizations", "id": il["id"], "attributes": {"subtitle": SUBTITLE, "privacyPolicyUrl": PRIVACY_URL}}})
    log(f"부제·개인정보 URL 설정")
    v = version(a["id"], create=True); vl = version_loc(v["id"])
    api("PATCH", f"/v1/appStoreVersionLocalizations/{vl['id']}", {"data": {"type": "appStoreVersionLocalizations", "id": vl["id"], "attributes": {
        "description": DESCRIPTION, "keywords": KEYWORDS, "promotionalText": PROMO, "supportUrl": SUPPORT_URL}}})
    log("설명·키워드·프로모션·지원 URL 설정")

def cmd_screenshots(d=None):
    d = d or os.path.join(ROOT, "docs", "screenshots")
    files = sorted(glob.glob(os.path.join(d, "*.png")))
    if not files: raise SystemExit(f"PNG 없음: {d}")
    a = app(); v = version(a["id"], create=True); vl = version_loc(v["id"])
    for s in api("GET", f"/v1/appStoreVersionLocalizations/{vl['id']}/appScreenshotSets")["data"]:
        if s["attributes"]["screenshotDisplayType"] == "APP_DESKTOP":
            api("DELETE", f"/v1/appScreenshotSets/{s['id']}"); log("기존 APP_DESKTOP 세트 삭제")
    st = api("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": "APP_DESKTOP"}, "relationships": {"appStoreVersionLocalization": rel("appStoreVersionLocalizations", vl["id"])}}})["data"]
    for f in files:
        data = open(f, "rb").read(); name = os.path.basename(f)
        sc = api("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots", "attributes": {"fileName": name, "fileSize": len(data)}, "relationships": {"appScreenshotSet": rel("appScreenshotSets", st["id"])}}})["data"]
        for op in sc["attributes"]["uploadOperations"]:
            chunk = data[op["offset"]: op["offset"] + op["length"]]
            api(op["method"], op["url"], chunk, raw=True, headers={h["name"]: h["value"] for h in op["requestHeaders"]})
        api("PATCH", f"/v1/appScreenshots/{sc['id']}", {"data": {"type": "appScreenshots", "id": sc["id"], "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        for _ in range(60):
            state = api("GET", f"/v1/appScreenshots/{sc['id']}")["data"]["attributes"]["assetDeliveryState"]["state"]
            if state in ("COMPLETE", "FAILED"): break
            time.sleep(2)
        log(f"{name}: {state}")

def cmd_price():
    a = app()
    pts = api("GET", f"/v1/apps/{a['id']}/appPricePoints?filter[territory]=KOR&limit=200")["data"]
    free = [p for p in pts if float(p["attributes"]["customerPrice"]) == 0.0]
    if not free: raise SystemExit("무료 가격 포인트 못 찾음")
    body = {"data": {"type": "appPriceSchedules", "relationships": {"app": rel("apps", a["id"]), "baseTerritory": rel("territories", "KOR"),
            "manualPrices": {"data": [{"type": "appPrices", "id": "${price0}"}]}}},
            "included": [{"type": "appPrices", "id": "${price0}", "attributes": {"startDate": None}, "relationships": {"appPricePoint": rel("appPricePoints", free[0]["id"])}}]}
    api("POST", "/v1/appPriceSchedules", body); log("가격: 무료 (base KOR)")

def cmd_build():
    a = app(); v = version(a["id"], create=True)
    builds = [b for b in latest_build(a["id"]) if b["attributes"]["processingState"] == "VALID"]
    if not builds: raise SystemExit("처리 완료(VALID)된 빌드가 아직 없음 — Apple 처리 대기 후 재시도")
    b = builds[0]
    if b["attributes"].get("usesNonExemptEncryption") is None:
        api("PATCH", f"/v1/builds/{b['id']}", {"data": {"type": "builds", "id": b["id"], "attributes": {"usesNonExemptEncryption": False}}})
    api("PATCH", f"/v1/appStoreVersions/{v['id']}", {"data": {"type": "appStoreVersions", "id": v["id"], "relationships": {"build": rel("builds", b["id"])}}})
    log(f"빌드 {b['attributes']['version']} 연결, 암호화 면제 표시")

def cmd_review():
    a = app(); v = version(a["id"], create=True)
    c = {k: os.environ.get(f"ASC_CONTACT_{k}") for k in ("FIRST", "LAST", "PHONE", "EMAIL")}
    if not all(c.values()): raise SystemExit("ASC_CONTACT_FIRST/LAST/PHONE/EMAIL 환경변수 필요")
    attrs = {"contactFirstName": c["FIRST"], "contactLastName": c["LAST"], "contactPhone": c["PHONE"], "contactEmail": c["EMAIL"], "demoAccountRequired": False, "notes": REVIEW_NOTES}
    ex = api("GET", f"/v1/appStoreVersions/{v['id']}/appStoreReviewDetail").get("data")
    if ex: api("PATCH", f"/v1/appStoreReviewDetails/{ex['id']}", {"data": {"type": "appStoreReviewDetails", "id": ex["id"], "attributes": attrs}})
    else: api("POST", "/v1/appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails", "attributes": attrs, "relationships": {"appStoreVersion": rel("appStoreVersions", v["id"])}}})
    log("심사 연락처·메모 설정")

def cmd_submit():
    a = app(); v = version(a["id"])
    rs = api("POST", "/v1/reviewSubmissions", {"data": {"type": "reviewSubmissions", "attributes": {"platform": "MAC_OS"}, "relationships": {"app": rel("apps", a["id"])}}})["data"]
    api("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {"reviewSubmission": rel("reviewSubmissions", rs["id"]), "appStoreVersion": rel("appStoreVersions", v["id"])}}})
    api("PATCH", f"/v1/reviewSubmissions/{rs['id']}", {"data": {"type": "reviewSubmissions", "id": rs["id"], "attributes": {"submitted": True}}})
    log(f"✅ 심사 제출 완료 (submission {rs['id']})")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    steps = {"status": cmd_status, "metadata": cmd_metadata, "screenshots": lambda: cmd_screenshots(sys.argv[2] if len(sys.argv) > 2 else None),
             "price": cmd_price, "build": cmd_build, "review": cmd_review, "submit": cmd_submit}
    if cmd == "all":
        for s in ("metadata", "screenshots", "price", "build", "review"): log(f"\n== {s} =="); steps[s]()
        log("\n== status =="); cmd_status()
    else: steps[cmd]()
