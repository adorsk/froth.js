require('./common')
Froth = require('../lib/froth.coffee')

describe 'Froth Actions', ->

  # Clear sheets after each test.
  afterEach ->
    Froth.resetSheets()

  describe '#Froth.set', ->
    it 'should set rules in the default sheet', ->
      rules = {
        '.a' : {
          'color': 'blue'
        }
      }
      Froth.set(rules)
      sheet = Froth.getSheet()
      sheet.rules.should.eql(rules)

    it 'should set rules in the given sheet', ->
      sheetId = 'sheet1'
      rules = {
        '.a' : {
          'color': 'blue'
        }
      }
      Froth.set(rules, sheetId)
      sheet = Froth.getSheet(sheetId)
      sheet.rules.should.eql(rules)

    it 'should override rules if they exist', ->
      rules_0 = {
        '.a' : {
          'color': 'blue',
          'width': 100
        },
        '.b' : {
          'color': 'red'
        }
      }
      Froth.set(rules_0)
      rules_1 = {
        '.a' : {
          'color': 'orange'
        }
      }
      Froth.set(rules_1)
      sheet = Froth.getSheet()
      sheet.rules.should.eql({
        '.a' : {
          'color': 'orange'
        },
        '.b' : {
          'color': 'red'
        }
      })


  describe '#Froth.update', ->
    it 'should update rules', ->
      rules_0 = {
        '.a' : {
          'color': 'blue',
          'width': 100,
          'height': 200
        }
      }
      Froth.set(rules_0)
      rules_1 = {
        '.a' : {
          'color' : 'green',
          'width': 50,
          'background-color': 'blue'
        }
      }
      Froth.update(rules_1)
      sheet = Froth.getSheet()
      sheet.rules.should.eql({
        '.a' : {
          'color': 'green',
          'width': 50,
          'background-color': 'blue',
          'height': 200
        }
      })

  describe '#Froth.delete', ->
    it 'should remove rules in the default sheet'
    it 'should remove rules in the given sheet'

  describe '#Froth.addModule', ->
    it 'should add a module', ->
      frothMod = {
        config: {
          baseUrl: '/test/baseUrl/'
        },
        sheets: {
          'test1': {
            rules: {
              '.relative': {
                'background-image': 'url("relative.png")'
              }
              '.absolute': {
                'background-image': 'url("http://foo.com/absolute.png")'
              }
            }
          }
        }
      }

      Froth.addModule(frothMod)
      Froth.sheets['test1'].toJsonCss().should.eql({
        id: 'test1',
        rules: {
          '.relative': {
            'background-image': 'url("/test/baseUrl/relative.png")'
          },
          '.absolute': {
            'background-image': 'url("http://foo.com/absolute.png")'
          },
        },
        imports: [],
      })
    
