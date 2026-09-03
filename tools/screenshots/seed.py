#!/usr/bin/env python3
"""폴백: 타이핑이 안 될 때 데모 메모를 DB에 직접 삽입. HangulIndexer/HashtagParser 규칙을 그대로 재현.
usage: seed.py <hanjjok.sqlite>  (앱은 종료된 상태여야 함)"""
import sqlite3, sys, uuid, re
from datetime import datetime, timedelta, timezone

CHO = list("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
JUNG = ["ㅏ","ㅐ","ㅑ","ㅒ","ㅓ","ㅔ","ㅕ","ㅖ","ㅗ","ㅗㅏ","ㅗㅐ","ㅗㅣ","ㅛ","ㅜ","ㅜㅓ","ㅜㅔ","ㅜㅣ","ㅠ","ㅡ","ㅡㅣ","ㅣ"]
JONG = ["","ㄱ","ㄲ","ㄱㅅ","ㄴ","ㄴㅈ","ㄴㅎ","ㄷ","ㄹ","ㄹㄱ","ㄹㅁ","ㄹㅂ","ㄹㅅ","ㄹㅌ","ㄹㅍ","ㄹㅎ","ㅁ","ㅂ","ㅂㅅ","ㅅ","ㅆ","ㅇ","ㅈ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ"]
COMPAT = {"ㄳ":"ㄱㅅ","ㄵ":"ㄴㅈ","ㄶ":"ㄴㅎ","ㄺ":"ㄹㄱ","ㄻ":"ㄹㅁ","ㄼ":"ㄹㅂ","ㄽ":"ㄹㅅ","ㄾ":"ㄹㅌ","ㄿ":"ㄹㅍ","ㅀ":"ㄹㅎ","ㅄ":"ㅂㅅ","ㅘ":"ㅗㅏ","ㅙ":"ㅗㅐ","ㅚ":"ㅗㅣ","ㅝ":"ㅜㅓ","ㅞ":"ㅜㅔ","ㅟ":"ㅜㅣ","ㅢ":"ㅡㅣ"}

def decompose(ch):
    v = ord(ch)
    if 0xAC00 <= v <= 0xD7A3:
        i = v - 0xAC00
        return CHO[i // 588] + JUNG[(i % 588) // 28] + JONG[i % 28]
    return COMPAT.get(ch, ch.lower())

def jamo(s): return "".join(decompose(c) for c in s)
def choseong(s):
    out = []
    for c in s:
        v = ord(c)
        out.append(CHO[(v - 0xAC00) // 588] if 0xAC00 <= v <= 0xD7A3 else (c.lower()[:1] or c))
    return "".join(out)
def tags(s):
    seen, out = set(), []
    for t in re.findall(r"#([가-힣A-Za-z0-9_]+)", s):
        t = t.lower()
        if t not in seen: seen.add(t); out.append(t)
    return out

def ts(dt): return dt.timestamp() - 978307200  # timeIntervalSinceReferenceDate (2001-01-01 기준)

now = datetime.now().astimezone()
yday = now - timedelta(days=1)
folders = [("일", 0), ("아이디어", 1)]
notes = [  # (created, folder, content)
    (yday.replace(hour=10, minute=12), "일", "## 이번 주 정리\n- [x] 사이드노트 리서치 마무리\n- [ ] 초성 검색 스크린샷\n- [ ] 앱 아이콘 다듬기"),
    (yday.replace(hour=16, minute=40), "일", "회의 끝. 다음 주 화요일 3시 디자인 리뷰 #회의"),
    (now.replace(hour=9, minute=5), "아이디어", "> 좋은 도구는 손에 잡히지 않는다 — 쓰는 줄도 모르게"),
    (now.replace(hour=11, minute=30), None, "사이드노트 프로젝트 첫 메모. 카톡 나와의 채팅 대신 여기에 적어보기 #메모앱"),
    (now.replace(hour=13, minute=2), "아이디어", "**한지** 질감은 라이트에서만, 다크는 먹으로. 쪽빛은 액센트로만 #디자인"),
    (now.replace(hour=14, minute=48), "아이디어", "점심에 읽은 글: 메모는 저장이 아니라 흘려보내는 것"),
]
db = sqlite3.connect(sys.argv[1])
db.execute("DELETE FROM note_tag"); db.execute("DELETE FROM note"); db.execute("DELETE FROM folder")
fid = {}
for name, order in folders:
    fid[name] = str(uuid.uuid4()).upper()
    db.execute("INSERT INTO folder(id,name,sort_order,created_at) VALUES(?,?,?,?)", (fid[name], name, order, ts(yday)))
for created, folder, content in notes:
    nid = str(uuid.uuid4()).upper()
    db.execute("INSERT INTO note(id,content,created_at,updated_at,jamo,choseong,folder_id) VALUES(?,?,?,?,?,?,?)",
               (nid, content, ts(created), None, jamo(content), choseong(content), fid.get(folder)))
    for t in tags(content):
        db.execute("INSERT INTO note_tag(note_id,tag) VALUES(?,?)", (nid, t))
db.commit()
print("seeded", db.execute("SELECT COUNT(*) FROM note").fetchone()[0], "notes,", db.execute("SELECT COUNT(*) FROM folder").fetchone()[0], "folders")
