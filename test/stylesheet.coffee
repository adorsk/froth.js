require('./common')
Froth = require('../lib/froth')

describe 'Froth.Stylesheet', ->

  # Clear stylesheets after each test.
  afterEach ->
    Froth.reset()

  describe '#Stylesheet.toCss', ->
    it 'should generate a CSS document', ->
      rules = {
        '.a' : {
          'color': 'blue'
        }
      }
      Froth.set(rules)
      stylesheet = Froth.getStylesheet()
      cssDoc = stylesheet.toCss()
      cssDoc.should.eql("""
.a {
  color: blue
}

        """)
      console.log('"%s"', cssDoc)
