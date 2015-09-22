path = require 'path'
{XRegExp} = require 'xregexp'
helpers = require 'atom-linter'

class LinterPurescript
  lintProcess: null

  constructor: (@editors) ->

  lint: (textEditor) ->
    mkResult = (match) ->
      lineEnd = match.lineEnd || match.lineStart
      colEnd = match.colEnd || match.colStart
      return {
        type: match.type || "Error",
        text: match.message.replace(/\n/g, " "),
        filePath: match.file,
        range: [[match.lineStart-1, match.colStart-1], [lineEnd-1, colEnd-1]]
        multiline: true
      }

    return new Promise (resolve, reject) =>
      if !atom.config.get("ide-purescript.enableAtomLinter")
        resolve([])
        return

      buildCommand = atom.config.get("ide-purescript.buildCommand").split(/\s+/)
      command = buildCommand[0]
      args = buildCommand.slice(1)

      filePath = textEditor.getPath()
      dirs = (dir for dir in atom.project.rootDirectories when dir.contains(filePath))
      projDir = if dirs.length == 1 then dirs[0].path else filePath.replace(/src\/.*/, "")

      options = { cwd: projDir, stream: "stderr" }

      atom.notifications.addInfo "linter: compiling PureScript"
      helpers.exec(command, args, options)
        .then (result) =>
          matches = []

          moduleRegex = '^[^\n]*(?<type>Error|Warning) in module [^\n]+:(?<message>.*?)^[^\n]*See'
          XRegExp.forEach result, XRegExp(moduleRegex, "sm"), (match) ->
            matches.push(mkResult(match))


          regex = '^[^\n]*(?<type>Error|Warning) at (?<file>[^\n]*) line (?<lineStart>[0-9]+), column (?<colStart>[0-9]+) - line (?<lineEnd>[0-9]+), column (?<colEnd>[0-9]+):(?<message>.*?)^[^\n]*See'


          XRegExp.forEach result, XRegExp(regex, "sm"), (match) ->
            matches.push(mkResult(match))

          parseRegex = 'Unable to parse module:\n[^"]*"(?<file>[^"]+)" \\(line (?<lineStart>[0-9]+), column (?<colStart>[0-9]+)\\):(?<message>.*?)^[^\n]*See'
          XRegExp.forEach result, XRegExp(parseRegex, "sm"), (match) ->
            matches.push(mkResult(match))

          @editors.onCompiled()

          atom.notifications.addSuccess "linter: compiled PureScript"

          resolve(matches)
        .then null, (err) ->
          reject(err)


module.exports = LinterPurescript
