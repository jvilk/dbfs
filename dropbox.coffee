window.db = window.Dropbox

class BrowserFS.File.DropboxFile extends BrowserFS.File.PreloadFile
  syncSync: ->
    @_fs.client.write(@_path, @_buffer.toString(), (error, stat) ->
      console.log error if error
    )
    return

  closeSync: -> @syncSync()

class BrowserFS.FileSystem.Dropbox extends BrowserFS.FileSystem
  constructor: ->
    @init_client = new db.Client
      key: 'u8sx6mjp5bxvbg4'
      sandbox: true

    @init_client.authDriver(new db.AuthDriver.Redirect({rememberUser: true}))

    @init_client.authenticate((error, authed_client) =>
      if error
        console.error 'Error: could not connect to Dropbox.'
        console.error error
        return

      # debug
      authed_client.getUserInfo((error, info) ->
        console.log info.name
      )

      @client = authed_client
    )

  getName: -> 'Dropbox'

  @isAvailable: -> true# @client.isAuthenticated()

  isReadOnly: -> false

  supportsSymlinks: -> false

  # not sure
  supportsProps: -> false

  supportsSynch: -> false

  rename: (oldPath, newPath, cb) ->
    @client.move(oldPath, newPath, (error, stat) ->
      cb error if error
    )

  stat: (path, isLstat, cb) ->
    @client.stat(path, {}, (error, stat) ->
      cb(error, stat)
    )

  open: (path, flags, mode, cb) ->
    fs = this
    @client.readFile(path, {}, (error, contents, stat, range) ->
      file = new BrowserFS.File.DropboxFile(fs, path, mode, stat, contents)
      cb(error, file)
    )

  _remove: (path, cb) ->
    @client.remove(path, (error, stat) ->
      cb error if error
    )

  unlink: (path, cb) -> @_remove(path, cb)

  rmdir: (path, cb) -> @_remove(path, cb)

  mkdir: (path, mode, cb) ->
    @client.mkdir(path, (error, stat) ->
      cb error if error
    )

  readdir: (path, cb) ->
    @client.readdir(path, {}, (error, files, dir_stat, content_stats) ->
      cb(error, files)
    )

  writeFile: (fname, data, encoding, flag, mode, cb) ->
    @open(fname, flag, mode, (error, file) ->
      file.write(data, 0, data.length, 0, (error) ->
        cb err
      )
    )


