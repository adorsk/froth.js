PORT = 3000
HOST = 'localhost'
BASE_URL = "http://#{HOST}:#{PORT}"
DECORADO_PATH = '/decorado.js'

stitch = require('stitch')
express = require('express')

pkg = stitch.createPackage({
  #paths: [__dirname +  '/foogie']
  paths: [__dirname +  '/../lib']
})
app = express()
app.get(DECORADO_PATH, pkg.createServer())
app.get('/foo', (req, res) ->
  res.send """
  <html><head>
  <script type="text/javascript" src="#{BASE_URL + DECORADO_PATH}"></script>
  </head><body>foasdf</body></html>
  """
)

app.listen(3000)
