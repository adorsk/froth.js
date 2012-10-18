require('./common')
Froth = require('../lib/froth')
frothc = require('../lib/frothc')
fs = require('fs')
wrench = require('wrench')

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
    # Create temporary dirs and mock assets, and setup bundling config.
    beforeEach ->
      this.dirs = {}
      this.dirs.tmpBaseDir = '/tmp/frothc.test.' + process.pid
      this.dirs.tmpAssets = this.dirs.tmpBaseDir + '/assets'
      this.dirs.tmpBundleDir = this.dirs.tmpBaseDir + '/bundle'
      for dirName, path of this.dirs
        fs.mkdirSync(path)

      # Setup assets and rewrite rules.
      this.mockAssets = [
        'fooDir/foo.png',
        'barDir/bar.png'
      ]

      this.mockPathsKeys = {
        'path1' : 'key1',
        'path2' : 'key2',
      }

      this.rewriteRules = {}

      for path, key of this.mockPathsKeys
        this.rewriteRules[path + '\/'] = {
          targetKey: key,
          sourceDir: this.dirs.tmpAssets + '/' + path
        }
        for mockAsset in this.mockAssets
          mockAssetPath = path + '/' + mockAsset
          assetRelDir = mockAssetPath.replace(/[^\/]*$/, '')
          wrench.mkdirSyncRecursive(this.dirs.tmpAssets + '/' + assetRelDir)
          fs.writeFile(this.dirs.tmpAssets + '/' + mockAssetPath, mockAsset + ' content')

      Froth.config.bundling = {
        baseRewriteUrl: '/new/base',
        bundleDir: this.dirs.tmpBundleDir,
        rewriteRules: this.rewriteRules
      }
    
    # Remove temporary dirs.
    afterEach ->
      wrench.rmdirSyncRecursive(this.dirs.tmpBaseDir)
      Froth.reset()

    it 'should bundle assets', ->
      # Set up rules w/ test assets.
      test_urls = {}
      i = 0
      expected_files = []
      for path, key of this.mockPathsKeys
        for mockAsset in this.mockAssets
          selector = 's_' + i
          key = this.mockPathsKeys[path]
          targetRelPath = '/' + key + '/' + mockAsset
          test_urls[selector] = {
            original: path + '/' + mockAsset,
            expected: Froth.config.bundling.baseRewriteUrl + targetRelPath
          }
          expected_files.push(Froth.config.bundling.bundleDir + targetRelPath)
          i += 1

      test_rules = {}
      expected_rules = {}
      for selector, urls of test_urls
        test_rules[selector] = {
          'property': "url('#{urls.original}')"
        }
        expected_rules[selector] = {
          'property': "url('#{urls.expected}')"
        }

      Froth.set(test_rules)
      frothc.bundleAssets()
      stylesheet = Froth.stylesheets[Froth.defaultStylesheetId]

      # Check that rewritten urls are as expected.
      stylesheet.rules.should.eql(expected_rules)

      # Check that bundle includes expected files.
      actual_files = []
      for item in wrench.readdirSyncRecursive(this.dirs.tmpBundleDir)
        item = this.dirs.tmpBundleDir + '/' + item
        if fs.statSync(item).isFile()
          actual_files.push(item)

      actual_files.sort().should.eql(expected_files.sort())
