import SwiftGodot

/// The green-phosphor look: colors, the monospace font and the theme every
/// screen inherits from the root.
enum Phosphor {
    static var background: Color { Color(r: 0.02, g: 0.06, b: 0.03, a: 1) }
    static var panel: Color { Color(r: 0.03, g: 0.10, b: 0.05, a: 1) }
    static var bright: Color { Color(r: 0.45, g: 1.00, b: 0.55, a: 1) }
    static var green: Color { Color(r: 0.20, g: 0.85, b: 0.35, a: 1) }
    static var dim: Color { Color(r: 0.10, g: 0.42, b: 0.18, a: 1) }
    static var amber: Color { Color(r: 1.00, g: 0.69, b: 0.00, a: 1) }
    static var red: Color { Color(r: 1.00, g: 0.30, b: 0.25, a: 1) }

    /// The theme on the root control. Children take its font, colors and
    /// panel styles, so a screen only overrides what is different.
    static func theme() -> Theme {
        let theme = Theme()
        let font = SystemFont()
        font.fontNames = PackedStringArray(["Menlo", "Monaco", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
        theme.defaultFont = font
        theme.defaultFontSize = 16
        for type in ["Label", "Button"] {
            theme.setColor(name: "font_color", themeType: StringName(type), color: green)
        }
        theme.setColor(name: "font_hover_color", themeType: "Button", color: bright)
        theme.setColor(name: "font_pressed_color", themeType: "Button", color: background)
        theme.setColor(name: "font_disabled_color", themeType: "Button", color: dim)
        theme.setStylebox(name: "panel", themeType: "PanelContainer", texture: box(fill: panel, border: dim))
        theme.setStylebox(name: "normal", themeType: "Button", texture: box(fill: panel, border: green))
        theme.setStylebox(name: "hover", themeType: "Button", texture: box(fill: panel, border: bright, width: 2))
        theme.setStylebox(name: "pressed", themeType: "Button", texture: box(fill: green, border: bright))
        theme.setStylebox(name: "disabled", themeType: "Button", texture: box(fill: background, border: dim))
        theme.setStylebox(name: "focus", themeType: "Button", texture: StyleBoxEmpty())
        theme.setStylebox(name: "background", themeType: "ProgressBar", texture: box(fill: background, border: dim))
        theme.setStylebox(name: "fill", themeType: "ProgressBar", texture: box(fill: green, border: green))
        return theme
    }

    /// A flat box with a 1-pixel (or `width`) border and a little padding.
    static func box(fill: Color, border: Color, width: Int32 = 1, padding: Double = 6) -> StyleBoxFlat {
        let style = StyleBoxFlat()
        style.bgColor = fill
        style.borderColor = border
        style.setBorderWidthAll(width: width)
        style.setContentMarginAll(offset: padding)
        return style
    }

    static func label(_ text: String, color: Color? = nil, size: Int32? = nil) -> Label {
        let label = Label()
        label.text = text
        if let color { label.addThemeColorOverride(name: "font_color", color: color) }
        if let size { label.addThemeFontSizeOverride(name: "font_size", fontSize: size) }
        return label
    }

    static func button(_ text: String, action: @escaping () -> Void) -> Button {
        let button = Button()
        button.text = text
        button.pressed.connect(action)
        return button
    }

    /// A labelled bar: `TRACE [=====     ] 40`.
    static func bar(_ title: String, value: Int, of max: Int, color: Color, width: Double = 160) -> HBoxContainer {
        let row = HBoxContainer()
        row.addChild(node: label(title))
        let bar = ProgressBar()
        bar.maxValue = Double(Swift.max(max, 1))
        bar.value = Double(value)
        bar.showPercentage = false
        bar.customMinimumSize = Vector2(x: Float(width), y: 14)
        bar.sizeFlagsVertical = .shrinkCenter
        bar.addThemeStyleboxOverride(name: "fill", stylebox: box(fill: color, border: color))
        row.addChild(node: bar)
        row.addChild(node: label("\(value)/\(max)"))
        return row
    }

    static func panel(_ content: Control) -> PanelContainer {
        let panel = PanelContainer()
        panel.addChild(node: content)
        return panel
    }

    static func vbox(separation: Int32 = 6, _ children: [Control] = []) -> VBoxContainer {
        let box = VBoxContainer()
        box.addThemeConstantOverride(name: "separation", constant: separation)
        for child in children { box.addChild(node: child) }
        return box
    }

    static func hbox(separation: Int32 = 12, _ children: [Control] = []) -> HBoxContainer {
        let box = HBoxContainer()
        box.addThemeConstantOverride(name: "separation", constant: separation)
        for child in children { box.addChild(node: child) }
        return box
    }

    /// A control that takes the free space in a box.
    static func spacer() -> Control {
        let spacer = Control()
        spacer.sizeFlagsHorizontal = .expandFill
        spacer.sizeFlagsVertical = .expandFill
        return spacer
    }
}
