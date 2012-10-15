require('coffee-script')
Decorado = require('../decorado')
require('should')

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
