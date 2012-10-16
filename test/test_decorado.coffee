require('./common')
{Decorado} = require('../lib/decorado')


describe 'Test Decorado', ->
  describe '#compile', ->
    c = new Decorado.Context()
    c.styles['style_1'] = {
      'rules' : {
        'selector1' : {
          'color': 'blue',
        }
      }
    }
    c.compile()
