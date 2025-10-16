# Shell (aka Corredor)

A wrapper to call shell commands from Swift code. A small part of the larger iOS deploy infrastructure at Plata.

## Usage

```swift
let result = Corredor.command(
    "git status", 
    arguments: ["--porcelain"], 
    options: .printOutput
).run()

// Working tree is clean! (or not)
...
```

If you're not into haha naming, just use `Shell.command...`, we understand.
