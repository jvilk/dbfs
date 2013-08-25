window.db = window.Dropbox

class BrowserFS.File.DropboxFile extends BrowserFS.File.PreloadFile
  sync: ->
    @_fs.client.writeFile(@_path, @_buffer.toString(), (error, stat) ->
      console.log error if error
    )

  close: -> @sync()

class BrowserFS.FileSystem.Dropbox extends BrowserFS.FileSystem
  constructor: (testing=false) ->
    @init_client = new db.Client
      key: 'u8sx6mjp5bxvbg4'
      sandbox: true

    if testing
      @init_client.setCredentials({
        key: "u8sx6mjp5bxvbg4",
        token: "mhkmZQTE4PUAAAAAAAAAAYyMdcdkqvPudyYwmuIZp3REM1YvV9skdtstDBYUxuFg",
        uid: "4326179"
      })
    else
      @init_client.authDriver(new db.AuthDriver.Redirect({
        rememberUser: true
      }))

    @init_client.authenticate((error, authed_client) =>
      if error
        console.error 'Error: could not connect to Dropbox'
        console.error error
        return

      authed_client.getUserInfo((error, info) ->
        console.debug "Successfully connected to #{info.name}'s Dropbox"
      )

      @client = authed_client
    )

  getName: -> 'Dropbox'

  # Dropbox.js works on all supported browsers and Node.js
  @isAvailable: -> true

  # Files can be written to Dropbox
  isReadOnly: -> false

  # Dropbox doesn't support symlinks, properties, or synchronous calls
  supportsSymlinks: -> false

  supportsProps: -> false

  supportsSynch: -> false

  empty: (cb) ->
    fs = this
    fs.client.readdir('/', (error, paths, dir, files) ->
      # XXX: Async hacks
      status = (false for file in files)
      for file, i in files
        fs.client.remove(file.path, (error, stat) ->
          status[i] = true
          unless false in status
            cb()
            return
        )
    )

  rename: (oldPath, newPath, cb) ->
    @client.move(oldPath, newPath, (error, stat) ->
      if error
        cb(new BrowserFS.ApiError(BrowserFS.ApiError.INVALID_PARAM, "#{path} doesn't exist"))
      else
        type = if stat.isFile
          BrowserFS.node.fs.Stats.FILE
        else
          BrowserFS.node.fs.Stats.DIRECTORY

        stat = new BrowserFS.node.fs.Stats(type, stat.size)
        cb(null, stat)
    )

  stat: (path, isLstat, cb) ->
    @client.stat(path, {}, (error, stat) ->
      if error
        console.log(error)
        cb(new BrowserFS.ApiError(BrowserFS.ApiError.INVALID_PARAM, "doesn't exist #{path}"))
      else
        type = if stat.isFile
          BrowserFS.node.fs.Stats.FILE
        else
          BrowserFS.node.fs.Stats.DIRECTORY

        stat = new BrowserFS.node.fs.Stats(type, stat.size)
        cb({message: path}, stat)
    )

  open: (path, flags, mode, cb) ->
    fs = this
    # Try and get the file's contents
    fs.client.readFile(path, {arrayBuffer: true}, (error, content, db_stat, range) =>
      if error
        if 'r' in flags
          cb(new BrowserFS.ApiError(BrowserFS.ApiError.INVALID_PARAM, "#{path} doesn't exist "))
        else
          switch error.status
            when 0
              console.error('No connection')
              return
            when 404
              console.log("File doesn't exist")
              content = ''
              fs.client.writeFile(path, content, (error, stat) ->
                db_stat = stat
                file = fs.convertStat(path, mode, db_stat, content)
                cb(null, file)
              )
              return
            else
              console.log(error)
              return
      else
        file = fs.convertStat(path, mode, db_stat, content)
        cb(null, file)

      return
    )

  convertStat: (path, mode, stat, data) ->
    type = if stat.isFile
      BrowserFS.node.fs.Stats.FILE
    else
      BrowserFS.node.fs.Stats.DIRECTORY

    stat = new BrowserFS.node.fs.Stats(type, stat.size)
    data or= ''

    buffer = new BrowserFS.node.Buffer(data)
    mode = new BrowserFS.FileMode('w')

    return new BrowserFS.File.DropboxFile(this, path, mode, stat, buffer)

  _remove: (path, cb) ->
    @client.remove(path, (error, stat) ->
      if error
        cb(new BrowserFS.ApiError(BrowserFS.ApiError.INVALID_PARAM, "Not deleted #{path}"))
      else
        cb(null)
    )

  unlink: (path, cb) -> @_remove(path, cb)

  rmdir: (path, cb) -> @_remove(path, cb)

  mkdir: (path, mode, cb) ->
    @client.mkdir(path, (error, stat) ->
      if error
        cb(new BrowserFS.ApiError(BrowserFS.ApiError.INVALID_PARAM, "#{path} already exists."))
      else
        cb(null)
    )

  readdir: (path, cb) ->
    @client.readdir(path, {}, (error, files, dir_stat, content_stats) ->
      cb(error, files)
    )

  writeFile: (fname, data, encoding, flag, mode, cb) ->
    fs = this
    @client.writeFile(fname, new BrowserFS.node.Buffer(data, encoding).toString(encoding), (error, stat) ->
      file = fs.convertStat(fname, mode, stat, data)
      cb(null, file)
    )

  readFile: (fname, encoding, flag, cb) ->
    fs = this
    # Try and get the file's contents
    fs.client.readFile(fname, (error, content, stat, range) =>
      if error
        cb(new BrowserFS.ApiError(BrowserFS.ApiError.INVALID_PARAM, "No such file #{fname}"))
        switch error.status
          when 0
            console.error('No connection')
          when 404
            console.log('File doesnt exist')
          else
            console.log(error)
      else
        cb(null, new BrowserFS.node.Buffer(content, encoding).toString(encoding))
    )
