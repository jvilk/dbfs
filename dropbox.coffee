window.db = window.Dropbox

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

  isAvailable: -> @client.isAuthenticated()

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
    @client.readFile((error, contents, stat, range) ->

    )

  unlink: (path, cb) ->

  rmdir: (path, cb) ->

  mkdir: (path, mode, cb) ->

  readdir: (path, cb) ->
