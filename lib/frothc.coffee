Froth = require('./froth')
src_file = process.argv[2]
src = require(src_file)
Froth.compile()
