# V Dashboard

## Description
A dashboard that displays the development progress of parts of V.

You can access a weekly updated version of this at [v.owo.computer](https://v.owo.computer/).

Currently it displays:
- The documentation progress of the vlibs (gets data from local v install)
- The test success rate of the go2v transpiler, based on passed tests (scrapes data from github)
- The test success rate of the c2v transpiler, based on passed tests (scrapes data from github)
- The progress to v0.1 of the ui library (scrapes data from github)

If you want another aspect tracked just create an issue that tells me what to track and how i could track that (or just create a PR adding it yourself if you dont wanna wait :p)

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

Generate statically rendered pages
```
v run . -prod -- --static
```

## Planed dashboard cards
- [ ] [SDL](https://github.com/vlang/sdl) (3.2.0 branch) - currently unclear how to track progress
- [ ] [Raylib for V](https://github.com/vlang/raylib) - currently unclear how to track progress
- [ ] [vlibsodium](https://github.com/vlang/libsodium) - currently unclear how to track progress

## Screenshots
![image](https://github.com/user-attachments/assets/dd30a2f9-f860-4793-adef-0a14914e5e69)
![image](https://github.com/user-attachments/assets/b3d3ab4c-3bca-4626-bb12-8d18a681c1ad)
![image](https://github.com/user-attachments/assets/602abafa-7eb6-4d75-a233-b9a25e1a46f2)
![image](https://github.com/user-attachments/assets/6f4fe8aa-5a98-4121-a188-56de07b62976)

