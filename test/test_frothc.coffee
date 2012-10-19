require('./common')
Froth = require('../lib/froth.coffee')
frothc = require('../lib/frothc.coffee')
fs = require('fs')
wrench = require('wrench')
$ = require('jquery')

class StringFile
  constructor: (value='') ->
    @value = value
  write: (data) ->
    @value += data
  toString: ->
    return @value

describe 'frothc', ->

  # Reset deferreds.
  beforeEach ->
    this.deferreds = []

  # Clear stylesheets after each test.
  afterEach ->
    $.when(this.deferreds...).then =>
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

  describe '#frothc.bundling', ->
    # Create temporary dirs and mock assets, and setup bundling config.
    beforeEach ->
      this.tmpDirs = {}
      this.tmpDirs.root = '/tmp/frothc.test.' + process.pid
      this.tmpDirs.assets = this.tmpDirs.root + '/assets'
      this.tmpDirs.bundle = this.tmpDirs.root + '/bundle'
      for dirName, path of this.tmpDirs
        fs.mkdirSync(path)

      # Setup assets and rewrite rules.
      this.mockAssets = [
        'fooDir/foo.png',
        'barDir/bar.png'
      ]

      this.mockPaths = [
        'path1',
        'path2'
      ]

      this.rewrites = []
      for path in this.mockPaths
        this.rewrites.push(
          [new RegExp("^#{path}/"), this.tmpDirs.assets + '/' + path + '/']
        )
        for mockAsset in this.mockAssets
          mockAssetPath = path + '/' + mockAsset
          assetRelDir = mockAssetPath.replace(/[^\/]*$/, '')
          wrench.mkdirSyncRecursive(this.tmpDirs.assets + '/' + assetRelDir)
          fs.writeFile(this.tmpDirs.assets + '/' + mockAssetPath, mockAsset + ' content')

      this.defaultBundlingConfig = {
        bundleBaseUrl: '/new/base',
        bundleDir: this.tmpDirs.bundle,
        rewrites: this.rewrites
      }

      this.defaultBundlingOpts = {
        sync: true
      }
    
    # Remove temporary dirs.
    afterEach ->
      $.when(this.deferreds...).then =>
        wrench.rmdirSyncRecursive(this.tmpDirs.root)
        this.deferreds = []

    it 'should bundle assets', ->
      deferred = $.Deferred()
      this.deferreds.push(deferred)
      try
        Froth.config.bundling = Froth.extend({}, this.defaultBundlingConfig, {
          baseUrl: '/new/base',
          bundleDir: this.tmpDirs.bundle,
        })
        # Set up rules w/ test assets.
        test_urls = {}
        i = 0
        expected_files = []
        for path in [this.mockPaths[0]]
          for mockAsset in this.mockAssets
            mockAssetPath = path + '/' + mockAsset
            mockAssetFilename = mockAssetPath.replace(/.*\//, '')
            selector = 's_' + i
            test_urls[selector] = {
              original: mockAssetPath
              expected: Froth.config.bundling.baseUrl + '/' + mockAssetFilename
            }
            filePath = Froth.config.bundling.bundleDir + '/' + mockAssetFilename
            filename = frothc.uniqueFilename(filePath)
            expected_files.push(Froth.config.bundling.bundleDir + '/' + filename)
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
        bundleDeferred = frothc.bundleAssets(this.defaultBundlingOpts)

        bundlePromise = $.when(bundleDeferred)
        bundlePromise.done =>
          stylesheet = Froth.stylesheets[Froth.defaultStylesheetId]

          # Check that rewritten urls are as expected.
          stylesheet.rules.should.eql(expected_rules)

          # Check that bundle includes expected files.
          actual_files = []
          for item in wrench.readdirSyncRecursive(this.tmpDirs.bundle)
            item = this.tmpDirs.bundle + '/' + item
            if fs.statSync(item).isFile()
              actual_files.push(item)

          actual_files.sort().should.eql(expected_files.sort())
          deferred.resolve()

        bundlePromise.fail =>
          deferred.resolve()
          throw JSON.stringify(arguments)

      catch error
        deferred.resolve()
