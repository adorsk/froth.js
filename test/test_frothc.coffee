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

      Froth.config.bundling = Froth.extend({}, this.defaultBundlingConfig, {
        baseUrl: '/new/base',
        bundleDir: this.tmpDirs.bundle,
      })
    
    # Remove temporary dirs.
    afterEach ->
      $.when(this.deferreds...).then =>
        wrench.rmdirSyncRecursive(this.tmpDirs.root)
        this.deferreds = []

    it.skip 'should bundle assets used in rules', ->
      deferred = $.Deferred()
      this.deferreds.push(deferred)

      # Set up rules w/ test assets.
      test_urls = {}
      i = 0
      expected_files = []
      for path in [this.mockPaths[0]]
        for mockAsset in this.mockAssets
          mockAssetPath = path + '/' + mockAsset
          rewrittenPath = frothc.rewriteUrl(mockAssetPath, this.rewrites)
          uniqueFilename = frothc.uniqueFilename(rewrittenPath)
          filePath = Froth.config.bundling.bundleDir + '/' + uniqueFilename

          selector = 's_' + i
          test_urls[selector] = {
            original: mockAssetPath,
            expected: Froth.config.bundling.baseUrl + '/' + uniqueFilename
          }
          expected_files.push(filePath)
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

    it 'should bundle assets used in imports', ->
      deferred = $.Deferred()
      this.deferreds.push(deferred)
      
      # Setup imports.
      this.mockImports = {
        'blue.css': 'body {background-color: blue;}',
        'green.css': 'body {background-color: green;}'
      }
      for path in [this.mockPaths[0]]
        for mockImport, content of this.mockImports
          importPath = path + '/' + mockImport
          relDir = importPath.replace(/[^\/]*$/, '')
          wrench.mkdirSyncRecursive(this.tmpDirs.assets + '/' + relDir)
          fs.writeFile(this.tmpDirs.assets + '/' + importPath, content)

      # Set up test imports.
      test_urls = {}
      i = 0
      expected_files = []
      for path in [this.mockPaths[0]]
        for mockAsset, content of this.mockImports
          mockAssetPath = path + '/' + mockAsset
          rewrittenPath = frothc.rewriteUrl(mockAssetPath, this.rewrites)
          uniqueFilename = frothc.uniqueFilename(rewrittenPath)
          filePath = Froth.config.bundling.bundleDir + '/' + uniqueFilename

          test_urls[mockAssetPath] = {
            original: mockAssetPath,
            expected: Froth.config.bundling.baseUrl + '/' + uniqueFilename
          }
          expected_files.push(filePath)
          i += 1

      test_imports = []
      expected_imports = []
      for import_, urls of test_urls
        test_imports.push({
          href: urls.original
        })
        expected_imports.push({
          href: urls.expected
        })

      Froth.addImports(test_imports)
      bundleDeferred = frothc.bundleAssets(this.defaultBundlingOpts)

      bundlePromise = $.when(bundleDeferred)
      bundlePromise.done =>
        stylesheet = Froth.stylesheets[Froth.defaultStylesheetId]

        # Check that rewritten imports are as expected.
        stylesheet.imports.should.eql(expected_imports)

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
