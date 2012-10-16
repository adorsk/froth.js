require('./common')
Froth = require('../lib/froth')

describe 'Froth Tests', ->
  describe '#frothJson', ->
    it 'should parse simple rules', ->
      result = Froth.frothJsonToJsonCss({
        'a': {
          'color': 'blue',
        }
      })
      result.should.eql({
        'a': {
          'color': 'blue'
        }
      })
      
    it 'should parse nested rules', ->
      result = Froth.frothJsonToJsonCss({
        'a': {
          'b' : {
            'color': 'blue'
          }
        }
      })
      result.should.eql({
        'a b': {
          'color': 'blue'
        }
      })

    it 'should parse nesting with "&"', ->
      result = Froth.frothJsonToJsonCss({
        'a': {
          '&:hover' : {
            'color': 'blue',
          }
        }
      })
      result.should.eql({
        'a:hover': {
          'color': 'blue'
        }
      })

    it 'should normalize selectors', ->
      result = Froth.frothJsonToJsonCss({
        '.c#a': {
          '&.b' : {
            'color': 'blue',
          }
        }
      })
      result.should.eql({
        '#a.b.c': {
          'color': 'blue'
        }
      })

    it 'should parse mixtures of nested rules and styles', ->
      result = Froth.frothJsonToJsonCss({
        'a': {
          'color': 'red',
          'b': {
            'color': 'blue'
          }
        }
      })
      result.should.eql({
        'a': {
          'color': 'red',
        },
        'a b': {
          'color': 'blue'
        }
      })

  describe '#merging', ->
    it 'should merge rules'
