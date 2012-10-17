require('./common')
stitch = require('stitch')
{Phantom, Sync} = require('phantom-sync')
express = require('express')

###
Helpers.
###

PORT = 3000
HOST = 'localhost'
BASE_URL = "http://#{HOST}:#{PORT}"
FROTH_PATH = '/froth.js'

{phantom,p, ver} = {}

# Setup a server that serves bundled Froth at '/froth.js'
createFrothApp = ->
  pkg = stitch.createPackage({
    paths: [__dirname +  '/../lib']
  })
  app = express()
  app.get(FROTH_PATH, pkg.createServer())
  return app

###
Tests.
###

describe 'Test Browser', ->
  beforeEach (done) ->
    this.app = createFrothApp()
    this.server = this.app.listen(3000)
    phantom = new Phantom
    done()
  afterEach (done) ->
    p.exit() if p?
    this.server.close() if this.server?
    done()
  describe '#assembly', ->
    it 'Should have global Froth variable', (done) ->
      test_path = '/test'
      this.app.get test_path, (req, res) ->
        res.send """
        <html><head>
        <script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.8.2/jquery.min.js"></script>
        <script type="text/javascript" src="#{BASE_URL + FROTH_PATH}"></script>
        </head>
        </html>
        """
      Sync ->
        p = phantom.create()
        page = p.createPage()
        page.open(BASE_URL + test_path)
        result = page.evaluate ->
          Froth = require('froth')
          c = new Froth.Context()
          c.styles['fish'] = {
            rules : {
              body: {
                'background-color': 'green'
              }
            }
          }
          c.compile()
          return $('body').css('background-color')
        console.log(result)
        done()
