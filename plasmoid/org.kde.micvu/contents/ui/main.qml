import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation
    readonly property string widgetVersion: "2026.03.10-14"

    property real level: 0.0
    property bool streamError: false
    property string statusText: "Initializing"
    property bool sampleInFlight: false

    readonly property string helperUrl: Qt.resolvedUrl("../helpers/mic_level").toString()
    readonly property string helperPath: helperUrl.startsWith("file://") ? helperUrl.substring(7) : helperUrl
    readonly property string startCommand: "\"" + root.helperPath + "\" --start"
    readonly property string readCommand: "\"" + root.helperPath + "\" --read"
    readonly property int pollMsSafe: Math.max(16, Number(plasmoid.configuration.pollMs || 20))
    readonly property real gainSafe: Math.max(1.0, Number(plasmoid.configuration.sensitivity || 16.0))
    readonly property real noiseFloorSafe: Math.max(0.0, Number(plasmoid.configuration.noiseFloor || 0.0))
    readonly property string tooltipMain: "Mic VU v" + root.widgetVersion + " - " + root.statusText

    toolTipMainText: root.tooltipMain

    function parseColorOrFallback(value, fallback) {
        const c = Qt.color(value)
        if (c.a === 0 && value !== "#00000000") {
            return Qt.color(fallback)
        }
        return c
    }

    function mixColors(a, b, t) {
        const clamped = Math.max(0, Math.min(1, t))
        return Qt.rgba(
            a.r + (b.r - a.r) * clamped,
            a.g + (b.g - a.g) * clamped,
            a.b + (b.b - a.b) * clamped,
            1.0
        )
    }

    readonly property color zeroColorSafe: parseColorOrFallback(plasmoid.configuration.zeroColor || "#b00020", "#b00020")
    readonly property color maxColorSafe: parseColorOrFallback(plasmoid.configuration.maxColor || "#00c853", "#00c853")
    readonly property color displayColor: streamError ? Qt.rgba(0.35, 0.35, 0.35, 1.0) : mixColors(zeroColorSafe, maxColorSafe, level)

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"

        onNewData: function(sourceName, data) {
            const out = (data["stdout"] || "").trim()
            const err = (data["stderr"] || "").trim()
            const exitCode = Number(data["exit code"] || 0)
            const isRead = sourceName.indexOf("--read") >= 0
            if (isRead) {
                root.sampleInFlight = false
            }

            if (!isRead) {
                if (exitCode !== 0 || err.length > 0) {
                    root.streamError = true
                    root.statusText = err.length > 0 ? err : "Sampler start failed"
                }
                executable.disconnectSource(sourceName)
                return
            }

            if (exitCode !== 0 || err.length > 0) {
                root.streamError = true
                root.statusText = err.length > 0 ? err : "Audio sampling failed"
            } else {
                const parsed = Number(out)
                if (!Number.isNaN(parsed)) {
                    const adjusted = Math.max(0, parsed - root.noiseFloorSafe) * root.gainSafe
                    let mappedLinear = Math.max(0, Math.min(1, adjusted))
                    if (parsed > root.noiseFloorSafe && mappedLinear < 0.03) {
                        mappedLinear = 0.03
                    }
                    const mapped = Math.sqrt(mappedLinear)
                    const attack = 0.0
                    const release = 0.55
                    const smooth = mapped > root.level ? attack : release
                    root.level = smooth * root.level + (1.0 - smooth) * mapped
                    root.streamError = false
                    root.statusText = "Mic level " + root.level.toFixed(3)
                } else {
                    root.streamError = true
                    root.statusText = "Invalid helper output"
                }
            }

            executable.disconnectSource(sourceName)
        }
    }

    Timer {
        id: pollTimer
        interval: root.pollMsSafe
        triggeredOnStart: true
        repeat: true
        running: true
        onTriggered: {
            if (root.sampleInFlight) {
                return
            }

            root.sampleInFlight = true
            executable.connectSource(root.readCommand)
        }
    }

    Component.onCompleted: {
        executable.connectSource(root.startCommand)
    }

    Component {
        id: liveRep

        Item {
            implicitWidth: 22
            implicitHeight: 22

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: root.streamError ? Qt.rgba(0.25, 0.08, 0.08, 0.95) : root.displayColor
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.20)
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                width: 13
                height: 13
                source: "audio-input-microphone"
                color: Qt.rgba(1, 1, 1, 0.95)
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 2
                anchors.rightMargin: 2
                anchors.bottomMargin: 1
                height: 2
                radius: 1
                width: Math.max(2, Math.round((parent.width - 4) * root.level))
                color: root.displayColor
                visible: !root.streamError
            }
        }
    }

    compactRepresentation: liveRep
    fullRepresentation: liveRep
}
