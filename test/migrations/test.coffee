this.up = (gorm) ->
  gorm.createTable 'cars', temporary: true, (t) ->
    t.text 'model'
    t.integer 'year'
  console.log "Created cars table."

  gorm.renameTable 'cars', 'vehicles'
  console.log "Renamed cars table to vehicles table."