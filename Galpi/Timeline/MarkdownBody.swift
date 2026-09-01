import SwiftUI
import Domain

/// 저장된 메모 카드의 마크다운 렌더러 — `MarkdownParser.blocks(in:)`가 줄 단위로 분해한
/// 블록을 마커가 사라진 완성형 서식으로 그린다.
/// QA r5-B 배경: `**HELLO WORLD**`가 별표째, `---`가 글자 그대로 카드에 보이던 버그
/// (스펙 §8 ⑫) — 이 뷰가 checklistBody를 대체해 모든 블록 타입을 렌더링한다.
/// 체크박스는 원형(Circle)이다 — 사용자 지시(QA r5): "`[ ]` 말고 그냥 동그라미로".
/// 저장되는 마크다운 문법 자체(`- [ ] `)는 그대로 두고, 그리는 모양만 원으로 바꾼다.
struct MarkdownBody: View {
    let content: String
    /// 체크박스 탭 → 호출부(NoteCardView)가 `ChecklistParser.toggling`으로 content를 갱신한다.
    let onToggle: (ChecklistItem) -> Void

    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    private var ink: Color { isDark ? GalpiTheme.inkDark : GalpiTheme.inkLight }
    private var inkSoft: Color { isDark ? GalpiTheme.inkSoftDark : GalpiTheme.inkSoftLight }
    private var jjok: Color { isDark ? GalpiTheme.jjokDark : GalpiTheme.jjokLight }

    /// 본문 lineSpacing 공식 — NoteCardView.contentText/checklistRow와 동일한 계산.
    private var bodyLineSpacing: CGFloat { (GalpiTheme.bodyLineHeightMultiple - 1) * 15 }

    var body: some View {
        let blocks = MarkdownParser.blocks(in: content)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                blockView(block, isFirst: index == 0)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock, isFirst: Bool) -> some View {
        switch block {
        case .heading(let level, let text, _):
            headingRow(level: level, text: text, isFirst: isFirst)
        case .divider:
            dividerRow
        case .checklist(let item):
            checklistRow(item)
        case .bullet(let text, _):
            bulletRow(text)
        case .quote(let text, _):
            quoteRow(text)
        case .paragraph(let text, _):
            paragraphRow(text)
        }
    }

    // MARK: - heading

    /// level 1~3 → 20 / 17.5 / 15.5. MarkdownParser.headingRegex가 `#{1,3}`만 매치하므로
    /// level은 이 세 값만 오지만, 방어적으로 그 외 값은 3단계 크기로 접어둔다.
    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 20
        case 2: return 17.5
        default: return 15.5
        }
    }

    private func headingRow(level: Int, text: String, isFirst: Bool) -> some View {
        Text(inline(text))
            .font(GalpiTheme.bodyBoldFont(size: headingSize(level)))
            .lineSpacing((GalpiTheme.bodyLineHeightMultiple - 1) * headingSize(level))
            .textSelection(.enabled)
            .padding(.top, isFirst ? 0 : 6)
            .padding(.bottom, 2)
    }

    // MARK: - divider

    private var dividerRow: some View {
        Rectangle()
            .fill(inkSoft.opacity(0.28))
            .frame(height: 1)
            .padding(.vertical, 7)
    }

    // MARK: - checklist

    /// 원형 체크박스 — 나머지 규격(20×20 히트 프레임, `.top` 정렬 + 광학 보정용
    /// `.padding(.top, 2.5)`)은 기존 사각형 버전(QA r3 ①)과 동일하게 유지한다.
    private func checklistRow(_ item: ChecklistItem) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Button {
                onToggle(item)
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(inkSoft.opacity(0.8), lineWidth: 1.5)
                        .opacity(item.isChecked ? 0 : 1)
                    Circle()
                        .fill(jjok)
                        .opacity(item.isChecked ? 1 : 0)
                    Image(systemName: "checkmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(item.isChecked ? 1 : 0)
                }
                .frame(width: 15, height: 15)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 2.5)

            Text(inline(item.text))
                .font(GalpiTheme.bodyFont())
                .lineSpacing(bodyLineSpacing)
                .strikethrough(item.isChecked)
                .foregroundStyle(item.isChecked ? inkSoft : ink)
                .textSelection(.enabled)
        }
    }

    // MARK: - bullet

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Text("•")
                .font(GalpiTheme.uiFont(size: 13))
                .foregroundStyle(inkSoft)
                .padding(.top, 2)
            Text(inline(text))
                .font(GalpiTheme.bodyFont())
                .lineSpacing(bodyLineSpacing)
                .textSelection(.enabled)
        }
        .padding(.leading, 2)
    }

    // MARK: - quote

    private func quoteRow(_ text: String) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(jjok.opacity(0.45))
                .frame(width: 2)
            Text(inline(text))
                .font(GalpiTheme.bodyFont())
                .lineSpacing(bodyLineSpacing)
                .foregroundStyle(inkSoft)
                .textSelection(.enabled)
                .padding(.leading, 9)
        }
    }

    // MARK: - paragraph

    /// 빈 문단(빈 줄)은 빈 Text 대신 고정 높이 스페이서로 렌더한다 — 빈 Text의 들쭉날쭉한
    /// 높이를 피하려는 조치(r2 리뷰 지적 사항, 브리프 명시).
    @ViewBuilder
    private func paragraphRow(_ text: String) -> some View {
        if text.isEmpty {
            Color.clear.frame(height: 6)
        } else {
            Text(inline(text))
                .font(GalpiTheme.bodyFont())
                .lineSpacing(bodyLineSpacing)
                .textSelection(.enabled)
        }
    }

    // MARK: - 인라인 서식

    /// `**굵게**` `*기울임*` `` `코드` `` `~~취소~~` 를 SwiftUI 기본 마크다운 파서로 처리한다.
    /// 블록 문법(제목·구분선·불릿·인용·체크리스트)은 이미 MarkdownParser가 처리했으므로
    /// 여기서는 인라인만 다룬다(`.inlineOnlyPreservingWhitespace`).
    /// 파싱 실패 시 원문 그대로 돌려준다 — 절대 크래시하거나 빈 텍스트를 내지 않는다.
    private func inline(_ s: String) -> AttributedString {
        (try? AttributedString(
            markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(s)
    }
}
