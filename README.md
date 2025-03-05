# V Dashboard

## Description
A dashboard that displays the development progress of parts of V.
Currently it displays:
- The documentation progress of the vlibs
- The test success rate of the go2v transpiler
- The progress to v0.1 of the ui library

## Usage
Put a github token in a `.env` file
```
GITHUB_TOKEN=<your token>
```

Run the dashboard (prod)
```
v run . -prod
```

Run the dashboard (dev)
```
v -d veb_livereload watch run .
```

## Screenshots
