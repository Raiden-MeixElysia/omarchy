.pragma library
.import "I18nZh.js" as Zh

// Shell text in the session's language; QML reaches this through the I18n singleton, plain JS imports it.
var chinese = Qt.locale().name.indexOf("zh_CN") === 0

function tr(text) {
  var args = arguments
  var template = chinese && Object.prototype.hasOwnProperty.call(Zh.table, text) ? Zh.table[text] : text
  // One pass, so an argument that itself contains %2 stays as given.
  return String(template).replace(/%(\d)/g, function(match, n) {
    return n > 0 && n < args.length ? String(args[n]) : match
  })
}

// Text a panel's own model builds in known formats: the first matching template is translated with what %1.. captured.
function trMatch(text, templates) {
  for (var i = 0; i < templates.length; i++) {
    var pattern = "^" + templates[i].replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace(/%\d/g, "(.+)") + "$"
    var match = String(text).match(new RegExp(pattern))
    if (match) return tr.apply(null, [templates[i]].concat(match.slice(1)))
  }
  return tr(text)
}
