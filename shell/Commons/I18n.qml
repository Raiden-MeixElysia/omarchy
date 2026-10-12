pragma Singleton
import QtQuick
import "Tr.js" as Tr

// tr("English %1", arg) returns the Chinese entry under zh_CN; plain JS imports Tr.js for the same.
QtObject {
  readonly property bool chinese: Tr.chinese

  function tr() {
    return Tr.tr.apply(null, arguments)
  }

  function trMatch(text, templates) {
    return Tr.trMatch(text, templates)
  }
}
