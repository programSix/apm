path = require 'path'
readline = require 'readline'

optimist = require 'optimist'

auth = require './auth'
Command = require './command'
fs = require './fs'
request = require './request'

module.exports =
class Unpublish extends Command
  @commandNames: ['unpublish']

  parseOptions: (argv) ->
    options = optimist(argv)

    options.usage """
      Usage: apm unpublish [<package_name>]
             apm unpublish <package_name>@<package_version>

      Remove a published package from the atom.io registry or unpublish a given
      version of a package.

      The package in the current working directory will be used if no package
      name is specified.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('f', 'force').boolean('force').describe('force', 'Do not prompt for confirmation')

  unpublishPackage: (packageName, packageVersion, callback) ->
    packageLabel = packageName
    packageLabel += "@#{packageVersion}" if packageVersion

    process.stdout.write "Unpublishing #{packageLabel} "

    auth.getToken (error, token) =>
      if error?
        @logFailure()
        callback(error)
        return

      options =
        uri: "https://atom.io/api/packages/#{packageName}"
        headers:
          authorization: token
        json: true

      options.uri += "/versions/#{packageVersion}" if packageVersion

      request.del options, (error, response, body={}) =>
        if error?
          @logFailure()
          callback(error)
        else if response.statusCode isnt 204
          @logFailure()
          message = body.message ? body.error ? body
          callback("Unpublishing failed: #{message}")
        else
          @logSuccess()
          callback()

  promptForConfirmation: (packageName, packageVersion, callback) ->
    prompt = readline.createInterface(process.stdin, process.stdout)

    packageLabel = packageName
    packageLabel += "@#{packageVersion}" if packageVersion

    prompt.question "Are you sure you want to unpublish #{packageLabel}? (yes) ", (answer) =>
      prompt.close()
      answer = if answer then answer.trim().toLowerCase() else 'yes'
      if answer is 'y' or answer is 'yes'
        @unpublishPackage(packageName, packageVersion, callback)

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    [name] = options.argv._

    atIndex = name?.indexOf('@')
    if atIndex > 0
      version = name.substring(atIndex + 1)
      name = name.substring(0, atIndex)

    unless name
      try
        name = JSON.parse(fs.readFileSync('package.json'))?.name

    unless name
      name = path.basename(process.cwd())

    if options.argv.force
      @unpublishPackage(name, version, callback)
    else
      @promptForConfirmation(name, version, callback)
