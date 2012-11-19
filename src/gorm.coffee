Future = require 'fibers/future'
pg = require 'pg'
path = require 'path'

# PostgreSQL DML
class PostgresAdapter
  # Takes a pg.Client
  constructor: (@client) ->

  save: (model, callback) =>
    if model.isPersisted()
      attrsString = ""
      for attribute, value of model.changedAttributes
        attrsString += "#{attribute}=#{@escape value}"
      @query """UPDATE #{@escape model.tableName} SET #{attrsString} WHERE id=#{@escape model.id}"""
    else
      numAttributes = 0
      namesArray = []
      valuesArray = []
      for attribute, value of model.changedAttributes
        numAttributes += 1
        namesArray.push(attribute)
        valuesArray.push(@escape value)
      valuesString = [0...numAttributes].map((i) -> "$#{i + 1}")
      @query """INSERT INTO #{@escape model.tableName} (#{namesArray.join(", ")}) VALUES (#{valuesString})""", valuesArray

  destroy: (model, callback) =>
    @query """DELETE FROM #{@escape model.tableName} WHERE id=#{@escape model.id}"""

  escape: (string) =>
    "'#{string.replace(/'/g, "''").replace(/\./g, '"."')}'"

  query: (args...) =>
    if typeof args[args.length - 1] == 'function'
      callback = args.pop()
      args.push (err, data) ->
        callback(err, data?.rows)
    @client.query(args...)

client = null

connect = (json) ->
  json ||= require(path.join(process.cwd(), 'databases.json'))

  # TODO: decide which database to use
  # TODO: Allow person to change the library used
  client = new pg.Client(json['development'])
  client.connect()

end = ->
  client.end()

getConnection = ->
  return getConnection.memoized  if getConnection.memoized?

  adapter = new PostgresAdapter(client)
  query = Future.wrap (sql, callback) ->
    adapter.query sql, (err, data) ->
      callback(err, data)

  getConnection.memoized = query
  query

createTable = (tableName, options, instructions) ->
  if arguments.length == 2
    instructions = options
    options = {}

  table = new Table(tableName, options)
  dsl = new DSL(table)
  instructions.call(dsl, dsl)

  query = getConnection()
  query(table.toSQL()).wait()

renameTable = (oldTableName, newTableName) ->
  query = getConnection()
  query("""ALTER TABLE #{oldTableName} RENAME TO #{newTableName}""").wait()

class DSL
  constructor: (@table) ->
  text: (columnName) =>
    @table.addColumn(columnName, 'TEXT')
  integer: (columnName) =>
    @table.addColumn(columnName, 'INTEGER')

class Table
  constructor: (@tableName, @options={}) ->
    @columns = []

  addColumn: (columnName, dataType) =>
    @columns.push(new Column(this, columnName, dataType))

  toSQL: =>
    """CREATE #{if @options.temporary || @options.temp then "TEMP " else ""}TABLE #{@tableName} (
      #{@columns.map((column) -> "#{column.columnName} #{column.dataType}").join(',')}
    )"""

  dropSQL: =>
    """DROP TABLE #{@tableName}"""

class Column
  constructor: (@table, @columnName, @dataType) ->
  addSQL: =>
    """ALTER TABLE #{@table.tableName} ADD #{@columnName} #{@dataType}"""
  changeSQL: =>
    """ALTER TABLE #{@table.tableName} MODIFY #{@columnName} #{@dataType}"""

gorm = {connect, end}
gorm.ddl = {createTable, renameTable}
module.exports = gorm
