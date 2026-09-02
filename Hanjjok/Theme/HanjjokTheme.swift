import SwiftUI
import AppKit
import os

private let themeLog = Logger(subsystem: "kr.hurdlers.Hanjjok", category: "theme")

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

/// docs/design/tokens.md (목업 승인: 2026-08-31) 의 값을 그대로 옮긴 것.
/// 색·치수를 바꿀 때는 tokens.md를 먼저 갱신하고 여기에 반영한다.
enum HanjjokTheme {
    // MARK: - 바탕 · 카드 · 본문 잉크

    static let paperLight = Color(hex: 0xE2D9C2)
    static let paperDark = Color(hex: 0x1C1A17)
    static let cardLight = Color(hex: 0xEFE8D6)
    static let cardDark = Color(hex: 0x25221E)
    static let inkLight = Color(hex: 0x2A2620)
    static let inkDark = Color(hex: 0xE8E0CE)
    static let inkSoftLight = Color(hex: 0x6E6559)
    static let inkSoftDark = Color(hex: 0x948B7A)
    static let inkMuteLight = Color(hex: 0x8A8070)
    static let inkMuteDark = Color(hex: 0x736B5D)

    // MARK: - 쪽빛 액센트

    static let jjokLight = Color(hex: 0x274C77)
    static let jjokDark = Color(hex: 0x7EA6CE)
    static let jjokWashLight = Color(hex: 0x274C77, alpha: 0.16)
    static let jjokWashDark = Color(hex: 0x7EA6CE, alpha: 0.20)

    // MARK: - 이음매(카드 사이 그림자 선)

    static let seamAboveLight = Color(hex: 0x2A2620, alpha: 0.24)
    static let seamBelowLight = Color(hex: 0xFFFBF0, alpha: 0.75)
    static let seamAboveDark = Color(hex: 0x000000, alpha: 0.45)
    static let seamBelowDark = Color(hex: 0xE8E0CE, alpha: 0.09)

    // MARK: - 카드 그림자 (이중 레이어: 주 그림자 + 밀착 윤곽 그림자)
    // Task 12에서 tokens.md "카드 그림자" 행을 그대로 옮겨 추가함 (Task 11에는 없었음).

    static let cardShadow1Light = Color(hex: 0x3C301E, alpha: 0.10)
    static let cardShadow2Light = Color(hex: 0x3C301E, alpha: 0.07)
    static let cardShadow1Dark = Color(hex: 0x000000, alpha: 0.34)
    static let cardShadow2Dark = Color(hex: 0xE8E0CE, alpha: 0.055)

    // MARK: - 저채도 오방색 (태그) — 청·적·황·백·흑, 라이트/다크 인덱스 대응

    static let tagColorsLight: [Color] = [
        Color(hex: 0x2E6B63),  // 청
        Color(hex: 0x9C3B33),  // 적
        Color(hex: 0x8A6420),  // 황
        Color(hex: 0x5F6A70),  // 백
        Color(hex: 0x3E3B4A),  // 흑
    ]
    static let tagColorsDark: [Color] = [
        Color(hex: 0x6FA79C),  // 청
        Color(hex: 0xC97F73),  // 적
        Color(hex: 0xC6A05C),  // 황
        Color(hex: 0x9FAEB6),  // 백
        Color(hex: 0x9A93AB),  // 흑
    ]
    static let tagChipAlpha = 0.12

    // MARK: - 결(그레인) 오버레이 — 패널 전체를 덮는 맨 위 레이어

    static let grainTintLight = Color(hex: 0x4A3D28)
    static let grainOpacityLight: Double = 0.16
    static let grainTintDark = Color(hex: 0xD8CDB4)
    static let grainOpacityDark: Double = 0.09
    /// 256pt 타일 (원본 512px @2x)
    static let grainTileSize: CGFloat = 256

    // MARK: - 치수

    static let cardPaddingV: CGFloat = 11
    static let cardPaddingH: CGFloat = 13
    static let cardRadius: CGFloat = 6
    static let cardSpacing: CGFloat = 8
    static let seamMarginTop: CGFloat = 22
    static let seamMarginBottom: CGFloat = 12
    static let panelHorizontalMargin: CGFloat = 16
    static let bodyLineHeightMultiple: CGFloat = 1.62

    // MARK: - 폰트

    static func bodyFont(size: CGFloat = 15) -> Font {
        UserDefaults.standard.bool(forKey: "usePretendardBody")
            ? .custom(FontName.pretendardRegular, size: size)
            : .custom(FontName.maruBuriRegular, size: size)
    }
    static func bodyNSFont(size: CGFloat = 15) -> NSFont {
        let usePretendard = UserDefaults.standard.bool(forKey: "usePretendardBody")
        let name = usePretendard ? FontName.pretendardRegular : FontName.maruBuriRegular
        if let font = NSFont(name: name, size: size) {
            return font
        }
        themeLog.fault("본문 폰트 '\(name, privacy: .public)' 로드 실패 — 시스템 폰트로 대체 (번들 손상 의심)")
        return .systemFont(ofSize: size)
    }
    /// 헤더 워드마크("한쪽") 전용 — MaruBuri Bold("SB급" 굵기). 본문(bodyFont)에는 쓰지 않는다.
    static func bodyBoldFont(size: CGFloat = 15) -> Font {
        guard NSFont(name: FontName.maruBuriBold, size: size) != nil else {
            themeLog.fault("굵은 본문 폰트 '\(FontName.maruBuriBold, privacy: .public)' 로드 실패 — 시스템 폰트로 대체 (번들 손상 의심)")
            return .system(size: size, weight: .semibold)
        }
        return .custom(FontName.maruBuriBold, size: size)
    }
    static func uiFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(weight == .semibold ? FontName.pretendardSemiBold : FontName.pretendardRegular, size: size)
    }

    /// 카드 안착 등 짧은 상태 변화를 감싸는 공용 모션 헬퍼 — 전부 ≤200ms, 시스템
    /// '동작 줄이기' 활성 시 애니메이션 없이 즉시 반영한다 (스펙 8장).
    @MainActor
    static func motion(_ body: () -> Void) {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { body() }
        else { withAnimation(.easeOut(duration: 0.2)) { body() } }
    }

    /// 태그 이름 → 결정적 색 배정 (재시작해도 같은 색)
    static func tagColor(_ tag: String, dark: Bool) -> Color {
        var h: UInt64 = 5381
        for b in tag.utf8 { h = (h &* 33) &+ UInt64(b) }
        let palette = dark ? tagColorsDark : tagColorsLight
        return palette[Int(h % UInt64(palette.count))]
    }
}

/// 번들에 등록된 실제 PostScript 이름. 파일명(MaruBuri-Regular.otf)과 다를 수 있어
/// 런치 시 `NSFontManager.shared.availableFonts`로 확인 후 고정한 값이다.
/// 실측: ["HiraMaruProN-W4", "MaruBuriot-Bold", "MaruBuriot-Regular",
///        "Pretendard-Regular", "Pretendard-SemiBold"]
enum FontName {
    static let maruBuriRegular = "MaruBuriot-Regular"
    static let maruBuriBold = "MaruBuriot-Bold"
    static let pretendardRegular = "Pretendard-Regular"
    static let pretendardSemiBold = "Pretendard-SemiBold"
}
