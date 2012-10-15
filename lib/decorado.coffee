require('coffee-script')
jsoncss = require('./jsoncss')

root = exports ? this

root.Context = class Context
  styles: {}

  compile: =>
    console.log('compile')
    compiled_css = {}
    for styleId, style of this.styles
      compiled_css[styleId] = jsoncss.dumpcss(style)
    console.log("compiled_css: %j", compiled_css)

