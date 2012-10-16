require('./common')
stitch = require('stitch')
{Phantom, Sync} = require('phantom-sync')
express = require('express')
Decorado = require('../lib/decorado')

###
Helpers.
###

PORT = 3000
HOST = 'localhost'
BASE_URL = "http://#{HOST}:#{PORT}"
DECORADO_PATH = '/decorado.js'

{phantom,p, ver} = {}

# Setup a server that serves bundled Decorado at '/decorado.js'
createDecoradoApp = ->
  pkg = stitch.createPackage({
    paths: [__dirname +  '/../lib']
  })
  app = express()
  app.get(DECORADO_PATH, pkg.createServer())
  return app

###
Tests.
###

describe 'Test Browser', ->
  beforeEach (done) ->
    this.app = createDecoradoApp()
    this.server = this.app.listen(3000)
    phantom = new Phantom
    done()
  afterEach (done) ->
    p.exit() if p?
    this.server.close() if this.server?
    done()
  describe '#assembly', ->
    it 'Should have global Decorado variable', (done) ->
      this.app.get('/foonko', (req, res) ->
        res.send """
        <html><head>
        <script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.8.2/jquery.min.js"></script>
        <script type="text/javascript" src="#{BASE_URL + DECORADO_PATH}"></script>
        </head>
        </html>
        """
      )
      Sync ->
        p = phantom.create()
        page = p.createPage()
        page.open(BASE_URL + '/foonko')
        result = page.evaluate ->
          dec = require('decorado').Decorado
          c = new dec.Context()
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
