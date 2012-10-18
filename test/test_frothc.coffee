require('./common')
Froth = require('../lib/froth')
frothc = require('../lib/frothc')

class StringFile
  constructor: (value='') ->
    @value = value
  write: (data) ->
    @value += data
  toString: ->
    return @value

describe 'frothc', ->

  # Clear stylesheets after each test.
  afterEach ->
    Froth.reset()

  describe.skip '#frothc.compile', ->
    it 'should generate a CSS document', ->
      rules = {
        '.a' : {
          'color': 'blue'
        }
      }
      Froth.set(rules)
      stylesheet = Froth.getStylesheet()
      strFile = new StringFile()
      frothc.compile({
        consolidateTo: strFile
      })
      strFile.value.should.eql("""
.a {
  color: blue
}

      """)

    it 'should consolidate stylesheets', ->
      Froth.set({
        '.a': {
          'color': 'blue'
        }
      }, 'stylesheet1')

      Froth.set({
        '.b': {
          'color': 'red'
        }
      }, 'stylesheet2')

      strFile = new StringFile()
      frothc.compile({
        consolidateTo: strFile
      })
      strFile.value.should.eql("""
.a {
  color: blue
}

.b {
  color: red
}

      """)

  describe '#frothc.bundleAssets', ->
    it 'should bundle assets', ->
      Froth.config.bundling = {
        baseRewriteUrl: '/new/base',
        bundleDir: 'bundled_assets',
        rewriteRules: {
          '/path1': 'key1'
        }
      }
      Froth.set({
        '.a': {
          'background-image': 'url("/path1/foo.png")'
        }
      })

      strFile = new StringFile()
      frothc.compile({
        consolidateTo: strFile
      })
