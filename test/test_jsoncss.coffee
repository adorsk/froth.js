require('./common')
Froth = require('../lib/froth.coffee')

describe 'JSONCSS', ->
  describe '#Froth.JsonCSS', ->
    afterEach ->
      Froth.reset()
    it 'should parse simple css text', ->
      css = '.a {color: blue;}'
      result = Froth.JsonCss.loadcss(css)
      result.rules.should.eql({
        '.a': {
          'color': 'blue'
        }
      })
      
    it 'should parse css text with "!important"', ->
      css = '.a {color: blue !important;}'
      result = Froth.JsonCss.loadcss(css)
      result.rules.should.eql({
        '.a': {
          'color': 'blue !important'
        }
      })

    it 'should normalize selectors"', ->
      css = '.c.b#a {color: blue;}'
      result = Froth.JsonCss.loadcss(css)
      result.rules.should.eql({
        '#a.b.c': {
          'color': 'blue'
        }
      })

    it 'should handle import rules', ->
      css = '@import url("beef");'
      result = Froth.JsonCss.loadcss(css)
      result.imports.should.eql({
        'beef': {
          'media': {
            length: 0
          }
        }
      })
