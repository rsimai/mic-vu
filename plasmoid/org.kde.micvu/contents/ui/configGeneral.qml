import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: root

    property alias cfg_zeroColor: zeroColorField.text
    property alias cfg_maxColor: maxColorField.text
    property alias cfg_pollMs: pollSpin.value
    property alias cfg_sensitivity: sensitivitySpin.value
    property alias cfg_noiseFloor: noiseFloorField.text

    implicitWidth: 420
    implicitHeight: 260

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Label {
            text: "Zero Level Color"
        }

        TextField {
            id: zeroColorField
            placeholderText: "#b00020"
            selectByMouse: true
            Layout.fillWidth: true
        }

        Label {
            text: "Max Level Color"
        }

        TextField {
            id: maxColorField
            placeholderText: "#00c853"
            selectByMouse: true
            Layout.fillWidth: true
        }

        Label {
            text: "Update Interval (ms)"
        }

        SpinBox {
            id: pollSpin
            from: 16
            to: 1000
            stepSize: 2
            editable: true
        }

        Label {
            text: "Sensitivity"
        }

        SpinBox {
            id: sensitivitySpin
            from: 1
            to: 500
            stepSize: 1
            editable: true
        }

        Label {
            text: "Noise Floor"
        }

        TextField {
            id: noiseFloorField
            placeholderText: "0.0"
            selectByMouse: true
            Layout.fillWidth: true
        }

        Label {
            text: "Use hex colors (#RRGGBB)."
            opacity: 0.7
        }
    }
}
