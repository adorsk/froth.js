try
  require('coffee-script')
catch err

jsoncss = require('./jsoncss')

root = exports ? this
root.Decorado = Decorado = {}

Decorado.Context = class Context
  styles: {}

  compile: =>
    console.log('compile')
    compiled_css = {}
    for styleId, style of this.styles
      compiled_css[styleId] = jsoncss.dumpcss(style)
    console.log("compiled_css: %j", compiled_css)
    # TODO: clean this up! Need better detection here.
    if window
      for styleId, compiledStyle of compiled_css
        styleEl = window.document.createElement("style")
        styleEl.type = "text/css";
        styleEl.innerHTML = compiledStyle
        window.document.head.appendChild(styleEl)

