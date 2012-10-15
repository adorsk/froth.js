require('./common')
stitch = require('stitch')
#phantom = require('phantom')
{Phantom, Sync} = require('phantom-sync')
express = require('express')
Decorado = require('../lib/decorado')

###
Helpers.
###

PORT = 3000
HOST = 'localhost'
BASE_URL = 'http://#{HOST}:#{PORT}'
DECORADO_PATH = '/decorado.js'

# Setup a server that serves bundled Decorado at '/decorado.js'
createDecoradoApp = ->
  pkg = stitch.createPackage({
    paths: [__dirname +  '/lib']
  })
  app = express()
  app.get(DECORADO_PATH, pkg.createServer())
  return app

# Setup a phantomjs page that includes bundled Decorado.
###
testWithDecoradoPage = (testFn) ->
  phantom.create (ph) ->
    ph.createPage (page) ->
      page.injectJs(BASE_URL + DECORADO_PATH)
      try
        testFn(page)
      catch error
        console.log("Error: ", error)
      ph.exit()
###
testWithDecoradoPage = (testFn) ->
  phantom = new Phantom
  Sync ->
    console.log('here')
    ph = phantom.create()
    console.log('here2')
    page = ph.createPage()
    page.injectJs(BASE_URL + DECORADO_PATH)
    try
      testFn(page)
    catch error
      console.log("Error: ", error)
    ph.exit()
  console.log('here3')

###
Tests.
###

describe 'Test Browser', ->
  beforeEach ->
    app = createDecoradoApp()
    this.server = app.listen(3000)
  afterEach ->
    this.server.close()
  describe '#assembly', ->
    it 'Should have global Decorado variable', ->
      testWithDecoradoPage ->
        console.log('foo')
