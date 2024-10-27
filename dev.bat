@echo off

@REM start /b npx nodemon --watch lib -d 1 -e lua,luau --exec "rojo sourcemap default.project.json --output sourcemap.json"
start /b npx nodemon --watch lib -e lua,luau --exec "darklua process lib/ lib-build/"
@REM start /b npx nodemon --watch dev -e lua,luau --exec "darklua process dev/ build/dev"
@REM start /b npx nodemon --watch wally.toml --exec "wally install"
