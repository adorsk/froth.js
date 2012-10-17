require('./common')
Froth = require('../lib/froth')

describe 'Froth Actions', ->
  describe '#Froth.set', ->
    it 'should set rules in the default stylesheet', ->
      rules = {
        '.a' : {
          'color': 'blue'
        }
      }
      Froth.set(rules)
      stylesheet = Froth.getStylesheet()
      stylesheet.rules.should.eql(rules)

    it 'should set rules in the given stylesheet', ->
      stylesheetId = 'stylesheet1'
      rules = {
        '.a' : {
          'color': 'blue'
        }
      }
      Froth.set(rules, stylesheetId)
      stylesheet = Froth.getStylesheet(stylesheetId)
      stylesheet.rules.should.eql(rules)

    it 'should override rules if they exist', ->
      t0_rules = {
        '.a' : {
          'color': 'blue',
          'width': 100
        },
        '.b' : {
          'color': 'red'
        }
      }
      Froth.set(t0_rules)
      t1_rules = {
        '.a' : {
          'color': 'orange'
        }
      }
      Froth.set(t1_rules)
      stylesheet = Froth.getStylesheet()
      stylesheet.rules.should.eql({
        '.a' : {
          'color': 'orange'
        },
        '.b' : {
          'color': 'red'
        }
      })


  describe '#Froth.update', ->
    it 'should update rules in the default stylesheet'
    it 'should update rules in the given stylesheet'

  describe '#Froth.delete', ->
    it 'should remove rules in the default stylesheet'
    it 'should remove rules in the given stylesheet'
